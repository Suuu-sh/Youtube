#!/usr/bin/env ruby
# frozen_string_literal: true

require 'date'
require 'json'
require 'net/http'
require 'optparse'
require 'time'
require 'uri'
require 'yaml'

ROOT = File.expand_path('..', __dir__)
VIDEOS_GLOB = File.join(ROOT, 'metadata/stock/**/stock.yaml')
JST = '+09:00'

CATEGORY_SCHEDULE = [
  { key: 'animal', name: '動物', publish: '07:30' },
  { key: 'food_drink', name: '食べ物・飲み物', publish: '12:00' },
  { key: 'body_health', name: '人体・健康', publish: '18:00' }
].freeze

CATEGORY_KEYS = CATEGORY_SCHEDULE.map { |category| category[:key] }.freeze
REQUIRED = %w[id category category_key level topic_key fact_summary status video_path title description].freeze
ACTIVE_STATUSES = %w[stock scheduled uploaded].freeze
USED_STATUSES = %w[scheduled uploaded].freeze
ALLOWED_STATUSES = (ACTIVE_STATUSES + %w[rejected]).freeze
DESCRIPTION_DETAIL_HEADING = '【詳細・補足】'
DETAIL_NUMBER_RE = /^\s*\d+\./
TOPIC_OVERLAP_STOP_WORDS = %w[
  animal animals food drink body health science tech scary danger
  lv1 lv2 lv3 lv4 lv5 level stock facts fact trivia basic basics
  storage safety principles functions category categories videos video
].freeze
DEFAULT_TOPIC_OVERLAP_MIN = 2
VISUAL_AUDIT_REQUIRED_AFTER = Time.new(2026, 4, 29, 12, 30, 0, JST)
VISUAL_AUDIT_REQUIRED_FLAGS = %w[
  contact_sheet_checked
  image_subject_match_checked
  no_unrelated_placeholder_images
  no_excessive_reuse
].freeze

class Error < StandardError; end

def load_local_youtube_env
  required = %w[YOUTUBE_CLIENT_ID YOUTUBE_CLIENT_SECRET YOUTUBE_REFRESH_TOKEN]
  return if required.all? { |key| ENV[key].to_s != '' }

  path = ENV.fetch('ZATSUGAKU_YOUTUBE_ENV', '/Users/yota/.codex/secrets/youtube_zatsugaku_api.env')
  return unless File.file?(path)

  File.foreach(path) do |line|
    stripped = line.strip
    next if stripped.empty? || stripped.start_with?('#')

    key, value = stripped.split('=', 2)
    next if key.to_s.empty? || value.nil?
    next unless required.include?(key)
    next if ENV[key].to_s != ''

    ENV[key] = value.strip.sub(/\A(['"])(.*)\1\z/, '\\2')
  end
end

module Inventory
  module_function

  def now
    Time.now.getlocal(JST)
  end

  def today
    Date.parse(now.strftime('%Y-%m-%d'))
  end

  def parse_date(value)
    return today if value.nil? || value == 'today'
    return today.next_day if value == 'tomorrow'

    Date.parse(value)
  end

  def level_for(date)
    case date.wday
    when 1, 3 then 'Lv1'
    when 2, 4 then 'Lv2'
    when 5 then 'Lv3'
    when 6 then 'Lv4'
    when 0 then 'Lv5'
    else raise Error, "Unsupported weekday: #{date.wday}"
    end
  end

  def timestamp(date, hhmm)
    hour = hhmm[0, 2].to_i
    minute = hhmm[3, 2].to_i
    slot_date = date + (hour / 24)
    Time.new(slot_date.year, slot_date.month, slot_date.day, hour % 24, minute, 0, JST).iso8601
  end

  def load_items
    Dir.glob(VIDEOS_GLOB).sort.map do |path|
      data = YAML.safe_load(File.read(path), permitted_classes: [Date, Time], aliases: false) || {}
      data = stringify_keys(data)
      data['_path'] = path
      data
    rescue Psych::Exception => e
      { '_path' => path, '_parse_error' => e.message }
    end
  end

  def stringify_keys(obj)
    case obj
    when Hash
      obj.each_with_object({}) { |(k, v), h| h[k.to_s] = stringify_keys(v) }
    when Array
      obj.map { |v| stringify_keys(v) }
    else
      obj
    end
  end

  def write_item(item)
    path = item.fetch('_path')
    data = item.reject { |k, _| k.start_with?('_') }
    File.write(path, "# Managed by scripts/zatsugaku_inventory.rb\n" + YAML.dump(data))
  end

  def validate_items(items)
    errors = []
    seen_ids = {}
    seen_topic_keys = {}
    items.each do |item|
      path = item['_path']
      if item['_parse_error']
        errors << "#{path}: YAML parse error: #{item['_parse_error']}"
        next
      end
      next if item['example'] == true

      REQUIRED.each do |key|
        value = item[key]
        errors << "#{path}: missing #{key}" if value.nil? || (value.respond_to?(:empty?) && value.empty?)
      end
      unless ALLOWED_STATUSES.include?(item['status'])
        errors << "#{path}: unknown status #{item['status'].inspect}"
      end
      if ACTIVE_STATUSES.include?(item['status']) && !description_has_details?(item['description'])
        errors << "#{path}: description must include #{DESCRIPTION_DETAIL_HEADING} and numbered detail notes"
      end
      if ACTIVE_STATUSES.include?(item['status']) && visual_audit_required?(item) && !visual_audit_complete?(item)
        errors << "#{path}: visual_audit must confirm contact_sheet_checked, image_subject_match_checked, no_unrelated_placeholder_images, and no_excessive_reuse"
      end
      if item['status'] == 'scheduled'
        %w[schedule_date publish_at publish_slot].each do |key|
          errors << "#{path}: scheduled item missing #{key}" if item[key].to_s.empty?
        end
      end
      if item['status'] == 'uploaded' && item['video_id'].to_s.empty?
        errors << "#{path}: uploaded item missing video_id"
      end
      unless CATEGORY_KEYS.include?(item['category_key'])
        errors << "#{path}: unknown category_key #{item['category_key'].inspect}"
      end
      unless %w[Lv1 Lv2 Lv3 Lv4 Lv5].include?(item['level'])
        errors << "#{path}: unknown level #{item['level'].inspect}"
      end
      if item['video_path'] && !File.exist?(item['video_path'])
        errors << "#{path}: video_path not found: #{item['video_path']}"
      end
      if item['id']
        errors << "#{path}: duplicate id #{item['id']} also in #{seen_ids[item['id']]}" if seen_ids[item['id']]
        seen_ids[item['id']] = path
      end
      if item['topic_key'] && ACTIVE_STATUSES.include?(item['status'])
        errors << "#{path}: duplicate active topic_key #{item['topic_key']} also in #{seen_topic_keys[item['topic_key']]}" if seen_topic_keys[item['topic_key']]
        seen_topic_keys[item['topic_key']] = path
      end
    end
    errors
  end

  def description_has_details?(description)
    text = description.to_s
    text.include?(DESCRIPTION_DETAIL_HEADING) && text.each_line.count { |line| line.match?(DETAIL_NUMBER_RE) } >= 3
  end

  def visual_audit_required?(item)
    raw = item['created_at'].to_s
    return true if raw.empty?

    Time.parse(raw) >= VISUAL_AUDIT_REQUIRED_AFTER
  rescue ArgumentError
    true
  end

  def visual_audit_complete?(item)
    audit = item['visual_audit']
    return false unless audit.is_a?(Hash)

    VISUAL_AUDIT_REQUIRED_FLAGS.all? { |key| audit[key] == true } &&
      audit['checked_at'].to_s != '' &&
      audit['notes'].to_s != ''
  end

  def normalize_text(value)
    value.to_s.downcase.gsub(/[\s　、。・,.!！?？「」『』（）()\[\]【】]/, '')
  end

  def similar?(a, b)
    aa = normalize_text(a)
    bb = normalize_text(b)
    return false if aa.empty? || bb.empty?
    return true if aa.include?(bb) || bb.include?(aa)

    grams_a = aa.each_char.each_cons(2).map(&:join).to_a.uniq
    grams_b = bb.each_char.each_cons(2).map(&:join).to_a.uniq
    return false if grams_a.empty? || grams_b.empty?

    intersection = (grams_a & grams_b).size.to_f
    union = (grams_a | grams_b).size.to_f
    intersection / union >= 0.72
  end

  def topic_tokens(item)
    item['topic_key'].to_s.downcase.split(/[^a-z0-9]+/).reject do |token|
      token.empty? || TOPIC_OVERLAP_STOP_WORDS.include?(token) || token.match?(/\A\d+\z/)
    end.uniq
  end

  def topic_overlap_reports(items, category_key: nil, level: nil, min_overlap: DEFAULT_TOPIC_OVERLAP_MIN)
    active = items.select do |item|
      item['example'] != true &&
        ACTIVE_STATUSES.include?(item['status']) &&
        item['_parse_error'].nil? &&
        (category_key.nil? || item['category_key'] == category_key) &&
        (level.nil? || item['level'] == level)
    end

    reports = []
    active.combination(2) do |a, b|
      next unless a['category_key'] == b['category_key']

      shared = topic_tokens(a) & topic_tokens(b)
      summary_similar = similar?(a['fact_summary'], b['fact_summary'])
      next unless shared.size >= min_overlap || summary_similar

      reports << {
        category_key: a['category_key'],
        level_pair: [a['level'], b['level']],
        ids: [a['id'], b['id']],
        shared_topic_tokens: shared,
        summary_similar: summary_similar,
        paths: [a['_path'], b['_path']],
        fact_summaries: [a['fact_summary'], b['fact_summary']]
      }
    end
    reports
  end

  def duplicate_with_used?(candidate, items)
    items.any? do |item|
      next false if item['_path'] == candidate['_path']
      next false unless USED_STATUSES.include?(item['status'])

      item['topic_key'] == candidate['topic_key'] || similar?(item['fact_summary'], candidate['fact_summary'])
    end
  end

  def stock_candidates(items, category_key, level)
    items.select do |item|
      item['example'] != true &&
        item['status'] == 'stock' &&
        item['category_key'] == category_key &&
        item['level'] == level &&
        visual_audit_complete?(item) &&
        File.exist?(item['video_path'].to_s)
    end.sort_by { |item| [item['created_at'].to_s, item['id'].to_s] }
  end

  def logical_publish_date(item)
    return Date.parse(item['schedule_date'].to_s) if item['schedule_date'].to_s != ''
    return nil if item['publish_at'].to_s == ''

    date = Date.parse(item['publish_at'].to_s[0, 10])
    slot_hour = item['publish_slot'].to_s[0, 2].to_i
    slot_hour >= 24 ? date - (slot_hour / 24) : date
  end

  def planned_for_category_date?(item, category_key, date)
    USED_STATUSES.include?(item['status']) &&
      item['category_key'] == category_key &&
      logical_publish_date(item) == date
  end

  def plan(date:, dry_run:)
    items = load_items
    errors = validate_items(items)
    raise Error, "Validation failed:\n- #{errors.join("\n- ")}" unless errors.empty?

    level = level_for(date)
    selected = []
    CATEGORY_SCHEDULE.each do |category|
      existing = items.find { |item| planned_for_category_date?(item, category[:key], date) }
      if existing
        selected << existing.merge('_already_planned' => true)
        next
      end

      candidate = stock_candidates(items, category[:key], level).find do |item|
        !duplicate_with_used?(item, items + selected)
      end
      raise Error, "No usable stock for #{category[:name]} #{level}" unless candidate

      candidate['status'] = 'scheduled'
      candidate['schedule_date'] = date.to_s
      candidate['scheduled_at'] = now.iso8601
      candidate['publish_at'] = timestamp(date, category[:publish])
      candidate['publish_slot'] = category[:publish]
      candidate['last_error'] = nil
      selected << candidate
    end

    selected.reject { |item| item['_already_planned'] }.each { |item| write_item(item) } unless dry_run
    puts JSON.pretty_generate(
      date: date.to_s,
      level: level,
      dry_run: dry_run,
      selected: selected.map { |i| i.slice('id', 'category', 'level', 'status', 'publish_at', 'publish_slot', '_path') }
    )
  end

  def due_uploads(items)
    items.select do |item|
      item['example'] != true &&
        item['status'] == 'scheduled' &&
        item['video_id'].to_s.empty? &&
        item['publish_at'] &&
        visual_audit_complete?(item) &&
        File.exist?(item['video_path'].to_s)
    end.sort_by { |item| item['publish_at'].to_s }
  end

  def planned_for_date?(items, date)
    CATEGORY_SCHEDULE.all? do |category|
      items.any? { |item| planned_for_category_date?(item, category[:key], date) }
    end
  end

  def stock_pool(items)
    pool = Hash.new { |hash, key| hash[key] = [] }
    items.each do |item|
      next if item['example'] == true
      next unless item['status'] == 'stock'
      next unless visual_audit_complete?(item)
      next unless File.exist?(item['video_path'].to_s)

      pool[[item['level'], item['category_key']]] << item
    end
    pool.each_value { |values| values.sort_by! { |item| [item['created_at'].to_s, item['id'].to_s] } }
    pool
  end

  def next_missing_set(from:, horizon_days:)
    items = load_items
    errors = validate_items(items)
    raise Error, "Validation failed:\n- #{errors.join("\n- ")}" unless errors.empty?

    pool = stock_pool(items)
    simulated = []
    (0...horizon_days).each do |offset|
      date = from + offset
      level = level_for(date)
      if planned_for_date?(items, date)
        simulated << { date: date.to_s, level: level, covered_by: 'planned' }
        next
      end

      missing = CATEGORY_SCHEDULE.select do |category|
        pool[[level, category[:key]]].empty?
      end
      unless missing.empty?
        return {
          date: date.to_s,
          level: level,
          missing_categories: missing.map { |category| { key: category[:key], name: category[:name] } },
          simulated_covered_dates: simulated
        }
      end

      CATEGORY_SCHEDULE.each { |category| pool[[level, category[:key]]].shift }
      simulated << { date: date.to_s, level: level, covered_by: 'stock' }
    end

    {
      date: nil,
      level: nil,
      missing_categories: [],
      simulated_covered_dates: simulated,
      message: "No missing set within #{horizon_days} days"
    }
  end
end

class YouTubeClient
  TOKEN_URI = URI('https://oauth2.googleapis.com/token')
  UPLOAD_URI = 'https://www.googleapis.com/upload/youtube/v3/videos?uploadType=resumable&part=snippet,status'
  RETRYABLE_ERRORS = [
    SocketError,
    EOFError,
    Errno::ECONNRESET,
    Errno::ECONNREFUSED,
    Errno::EHOSTUNREACH,
    Errno::ENETUNREACH,
    Net::OpenTimeout,
    Net::ReadTimeout
  ].freeze
  DEFAULT_RETRY_ATTEMPTS = 3
  DEFAULT_RETRY_BASE_DELAY = 1.0

  def initialize
    missing = %w[YOUTUBE_CLIENT_ID YOUTUBE_CLIENT_SECRET YOUTUBE_REFRESH_TOKEN].select { |key| ENV[key].to_s.empty? }
    raise Error, "Missing YouTube API credentials: #{missing.join(', ')}" unless missing.empty?

    @client_id = ENV.fetch('YOUTUBE_CLIENT_ID')
    @client_secret = ENV.fetch('YOUTUBE_CLIENT_SECRET')
    @refresh_token = ENV.fetch('YOUTUBE_REFRESH_TOKEN')
  end

  def with_retries(action, attempts: DEFAULT_RETRY_ATTEMPTS, base_delay: DEFAULT_RETRY_BASE_DELAY)
    tries = 0

    begin
      tries += 1
      yield
    rescue *RETRYABLE_ERRORS => e
      raise if tries >= attempts

      delay = base_delay * (2**(tries - 1))
      warn "#{action} retry #{tries}/#{attempts - 1} after #{e.class}: #{e.message} (sleep #{delay}s)"
      sleep(delay)
      retry
    end
  end

  def access_token
    with_retries('OAuth refresh') do
      req = Net::HTTP::Post.new(TOKEN_URI)
      req.set_form_data(
        client_id: @client_id,
        client_secret: @client_secret,
        refresh_token: @refresh_token,
        grant_type: 'refresh_token'
      )
      res = Net::HTTP.start(TOKEN_URI.hostname, TOKEN_URI.port, use_ssl: true) { |http| http.request(req) }
      raise Error, "OAuth refresh failed: HTTP #{res.code} #{res.body}" unless res.is_a?(Net::HTTPSuccess)

      JSON.parse(res.body).fetch('access_token')
    end
  end

  def upload_video(item)
    token = access_token
    file = item.fetch('video_path')
    body = {
      snippet: {
        title: item.fetch('title'),
        description: item.fetch('description'),
        categoryId: '22'
      },
      status: {
        privacyStatus: 'private',
        publishAt: Time.parse(item.fetch('publish_at')).utc.iso8601,
        selfDeclaredMadeForKids: false
      }
    }.to_json

    uri = URI(UPLOAD_URI)
    init = Net::HTTP::Post.new(uri)
    init['Authorization'] = "Bearer #{token}"
    init['Content-Type'] = 'application/json; charset=UTF-8'
    init['X-Upload-Content-Type'] = 'video/mp4'
    init['X-Upload-Content-Length'] = File.size(file).to_s
    init.body = body
    init_res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http| http.request(init) }
    unless init_res.is_a?(Net::HTTPRedirection) || init_res.code.to_i == 200
      raise Error, "Upload init failed: HTTP #{init_res.code} #{init_res.body}"
    end
    location = init_res['Location']
    raise Error, 'Upload init failed: missing Location header' if location.to_s.empty?

    upload_uri = URI(location)
    put = Net::HTTP::Put.new(upload_uri)
    put['Authorization'] = "Bearer #{token}"
    put['Content-Type'] = 'video/mp4'
    put.body = File.binread(file)
    put_res = Net::HTTP.start(upload_uri.hostname, upload_uri.port, use_ssl: true) { |http| http.request(put) }
    raise Error, "Upload body failed: HTTP #{put_res.code} #{put_res.body}" unless put_res.is_a?(Net::HTTPSuccess)

    body = JSON.parse(put_res.body)
    video_id = body['id'].to_s
    raise Error, "Upload succeeded but response did not include video id: #{put_res.body}" if video_id.empty?

    video_id
  end
end

class Hash
  def slice(*keys)
    keys.each_with_object({}) { |key, out| out[key] = self[key] if key? key }
  end
end

def usage
  warn <<~USAGE
    Usage:
      ruby scripts/zatsugaku_inventory.rb validate
      ruby scripts/zatsugaku_inventory.rb plan [--date YYYY-MM-DD|today] [--dry-run]
      ruby scripts/zatsugaku_inventory.rb upload-due [--dry-run]
      ruby scripts/zatsugaku_inventory.rb next-missing-set [--date YYYY-MM-DD|today] [--horizon-days N]
      ruby scripts/zatsugaku_inventory.rb overlap-report [--category KEY] [--level LvN] [--min-overlap N] [--strict]
  USAGE
  exit 2
end

command = ARGV.shift || usage
options = { date: 'today', dry_run: false, horizon_days: 31, category: nil, level: nil, min_overlap: DEFAULT_TOPIC_OVERLAP_MIN, strict: false }
OptionParser.new do |opts|
  opts.on('--date DATE') { |v| options[:date] = v }
  opts.on('--dry-run') { options[:dry_run] = true }
  opts.on('--horizon-days N', Integer) { |v| options[:horizon_days] = v }
  opts.on('--category KEY') { |v| options[:category] = v }
  opts.on('--level LEVEL') { |v| options[:level] = v }
  opts.on('--min-overlap N', Integer) { |v| options[:min_overlap] = v }
  opts.on('--strict') { options[:strict] = true }
end.parse!(ARGV)

begin
  load_local_youtube_env

  case command
  when 'validate'
    items = Inventory.load_items
    errors = Inventory.validate_items(items)
    if errors.empty?
      puts "OK: #{items.count { |i| i['example'] != true }} metadata files"
    else
      warn errors.map { |e| "- #{e}" }.join("\n")
      exit 1
    end
  when 'plan'
    Inventory.plan(date: Inventory.parse_date(options[:date]), dry_run: options[:dry_run])
  when 'next-missing-set'
    target = Inventory.next_missing_set(from: Inventory.parse_date(options[:date]), horizon_days: options[:horizon_days])
    puts JSON.pretty_generate(target)
  when 'overlap-report'
    items = Inventory.load_items
    errors = Inventory.validate_items(items)
    raise Error, "Validation failed:\n- #{errors.join("\n- ")}" unless errors.empty?

    reports = Inventory.topic_overlap_reports(
      items,
      category_key: options[:category],
      level: options[:level],
      min_overlap: options[:min_overlap]
    )
    puts JSON.pretty_generate(overlap_count: reports.size, min_overlap: options[:min_overlap], reports: reports)
    exit 1 if options[:strict] && reports.any?
  when 'upload-due'
    items = Inventory.load_items
    errors = Inventory.validate_items(items)
    raise Error, "Validation failed:\n- #{errors.join("\n- ")}" unless errors.empty?

    due = Inventory.due_uploads(items)
    client = options[:dry_run] ? nil : YouTubeClient.new
    due.each do |item|
      if options[:dry_run]
        puts "DRY upload #{item['id']} -> #{item['publish_at']}"
        next
      end
      begin
        item['video_id'] = client.upload_video(item)
        item['uploaded_at'] = Inventory.now.iso8601
        item['status'] = 'uploaded'
        item['last_error'] = nil
        puts "uploaded #{item['id']} -> #{item['video_id']}"
      rescue StandardError => e
        item['last_error'] = "#{e.class}: #{e.message}"
        warn "upload failed #{item['id']}: #{item['last_error']}"
      ensure
        Inventory.write_item(item)
      end
    end
    puts JSON.pretty_generate(upload_due_count: due.size, dry_run: options[:dry_run])
  else
    usage
  end
rescue StandardError => e
  warn "ERROR: #{e.message}"
  exit 1
end
