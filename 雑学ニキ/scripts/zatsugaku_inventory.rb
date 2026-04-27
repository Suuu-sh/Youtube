#!/usr/bin/env ruby
# frozen_string_literal: true

require 'date'
require 'fileutils'
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
  { key: 'animal', name: '動物', publish: '07:30', comment: '07:35' },
  { key: 'food_drink', name: '食べ物・飲み物', publish: '12:00', comment: '12:05' },
  { key: 'body_health', name: '人体・健康', publish: '18:00', comment: '18:05' },
  { key: 'science_tech', name: '科学・テクノロジー', publish: '21:00', comment: '21:05' },
  { key: 'scary_danger', name: '怖い・危険', publish: '25:00', comment: '25:05' }
].freeze

REQUIRED = %w[id category category_key level topic_key fact_summary status video_path title description comment_text].freeze
ACTIVE_STATUSES = %w[stock scheduled uploaded commented].freeze
USED_STATUSES = %w[scheduled uploaded commented].freeze
TOPIC_OVERLAP_STOP_WORDS = %w[
  animal animals food drink body health science tech scary danger
  lv1 lv2 lv3 lv4 lv5 level stock facts fact trivia basic basics
  storage safety principles functions category categories videos video
].freeze
DEFAULT_TOPIC_OVERLAP_MIN = 2

class Error < StandardError; end

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

  def last_day_of_month?(date)
    date.next_day.month != date.month
  end

  def level_for(date)
    return 'Lv5' if last_day_of_month?(date)

    case date.wday
    when 1, 3, 5 then 'Lv1'
    when 2, 4 then 'Lv2'
    when 6 then 'Lv3'
    when 0 then 'Lv4'
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
      unless CATEGORY_SCHEDULE.map { |c| c[:key] }.include?(item['category_key'])
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
        File.exist?(item['video_path'].to_s)
    end.sort_by { |item| [item['created_at'].to_s, item['id'].to_s] }
  end

  def plan(date:, dry_run:)
    items = load_items
    errors = validate_items(items)
    raise Error, "Validation failed:\n- #{errors.join("\n- ")}" unless errors.empty?

    level = level_for(date)
    selected = []
    CATEGORY_SCHEDULE.each do |category|
      existing = items.find do |item|
        USED_STATUSES.include?(item['status']) &&
          item['category_key'] == category[:key] &&
          item['publish_at'].to_s.start_with?(date.to_s)
      end
      if existing
        selected << existing.merge('_already_planned' => true)
        next
      end

      candidate = stock_candidates(items, category[:key], level).find do |item|
        !duplicate_with_used?(item, items + selected)
      end
      raise Error, "No usable stock for #{category[:name]} #{level}" unless candidate

      candidate['status'] = 'scheduled'
      candidate['scheduled_at'] = now.iso8601
      candidate['publish_at'] = timestamp(date, category[:publish])
      candidate['comment_after_at'] = timestamp(date, category[:comment])
      candidate['publish_slot'] = category[:publish]
      candidate['comment_slot'] = category[:comment]
      candidate['last_error'] = nil
      selected << candidate
    end

    selected.reject { |item| item['_already_planned'] }.each { |item| write_item(item) } unless dry_run
    puts JSON.pretty_generate(date: date.to_s, level: level, dry_run: dry_run, selected: selected.map { |i| i.slice('id', 'category', 'level', 'publish_at', 'comment_after_at', '_path') })
  end

  def due_uploads(items)
    items.select do |item|
      item['example'] != true && item['status'] == 'scheduled' && item['video_id'].to_s.empty? && item['publish_at'] && File.exist?(item['video_path'].to_s)
    end.sort_by { |item| item['publish_at'].to_s }
  end

  def due_comments(items, at: now)
    items.select do |item|
      item['example'] != true &&
        item['status'] == 'uploaded' &&
        item['video_id'].to_s != '' &&
        item['commented_at'].to_s == '' &&
        item['comment_after_at'] &&
        Time.parse(item['comment_after_at']) <= at
    end
  end

  def comments_due_for_slot(items, slot:, at: now)
    due_comments(items, at: at).select do |item|
      item['comment_slot'].to_s == slot.to_s || Time.parse(item['comment_after_at'].to_s).strftime('%H:%M') == slot.to_s
    end
  end

  def planned_for_date?(items, date)
    CATEGORY_SCHEDULE.all? do |category|
      items.any? do |item|
        item['example'] != true &&
          USED_STATUSES.include?(item['status']) &&
          item['category_key'] == category[:key] &&
          item['publish_at'].to_s.start_with?(date.to_s)
      end
    end
  end

  def stock_pool(items)
    pool = Hash.new { |hash, key| hash[key] = [] }
    items.each do |item|
      next if item['example'] == true
      next unless item['status'] == 'stock'
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
  COMMENT_URI = URI('https://www.googleapis.com/youtube/v3/commentThreads?part=snippet')

  def initialize
    missing = %w[YOUTUBE_CLIENT_ID YOUTUBE_CLIENT_SECRET YOUTUBE_REFRESH_TOKEN].select { |key| ENV[key].to_s.empty? }
    raise Error, "Missing YouTube API credentials: #{missing.join(', ')}" unless missing.empty?

    @client_id = ENV.fetch('YOUTUBE_CLIENT_ID')
    @client_secret = ENV.fetch('YOUTUBE_CLIENT_SECRET')
    @refresh_token = ENV.fetch('YOUTUBE_REFRESH_TOKEN')
  end

  def access_token
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

  def post_comment(item)
    token = access_token
    req = Net::HTTP::Post.new(COMMENT_URI)
    req['Authorization'] = "Bearer #{token}"
    req['Content-Type'] = 'application/json; charset=UTF-8'
    req.body = {
      snippet: {
        videoId: item.fetch('video_id'),
        topLevelComment: { snippet: { textOriginal: item.fetch('comment_text') } }
      }
    }.to_json
    res = Net::HTTP.start(COMMENT_URI.hostname, COMMENT_URI.port, use_ssl: true) { |http| http.request(req) }
    raise Error, "Comment failed: HTTP #{res.code} #{res.body}" unless res.is_a?(Net::HTTPSuccess)

    JSON.parse(res.body).fetch('id')
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
      ruby scripts/zatsugaku_inventory.rb comment-due [--dry-run]
      ruby scripts/zatsugaku_inventory.rb comment-due --slot HH:MM [--dry-run]
      ruby scripts/zatsugaku_inventory.rb next-missing-set [--date YYYY-MM-DD|today] [--horizon-days N]
      ruby scripts/zatsugaku_inventory.rb overlap-report [--category KEY] [--level LvN] [--min-overlap N] [--strict]
  USAGE
  exit 2
end

command = ARGV.shift || usage
options = { date: 'today', dry_run: false, slot: nil, horizon_days: 31, category: nil, level: nil, min_overlap: DEFAULT_TOPIC_OVERLAP_MIN, strict: false }
OptionParser.new do |opts|
  opts.on('--date DATE') { |v| options[:date] = v }
  opts.on('--dry-run') { options[:dry_run] = true }
  opts.on('--slot HH:MM') { |v| options[:slot] = v }
  opts.on('--horizon-days N', Integer) { |v| options[:horizon_days] = v }
  opts.on('--category KEY') { |v| options[:category] = v }
  opts.on('--level LEVEL') { |v| options[:level] = v }
  opts.on('--min-overlap N', Integer) { |v| options[:min_overlap] = v }
  opts.on('--strict') { options[:strict] = true }
end.parse!(ARGV)

begin
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
  when 'comment-due'
    items = Inventory.load_items
    errors = Inventory.validate_items(items)
    raise Error, "Validation failed:\n- #{errors.join("\n- ")}" unless errors.empty?

    due = if options[:slot]
            Inventory.comments_due_for_slot(items, slot: options[:slot])
          else
            Inventory.due_comments(items)
          end
    client = options[:dry_run] ? nil : YouTubeClient.new
    due.each do |item|
      if options[:dry_run]
        puts "DRY comment #{item['id']} -> #{item['video_id']}"
        next
      end
      begin
        item['comment_id'] = client.post_comment(item)
        item['commented_at'] = Inventory.now.iso8601
        item['status'] = 'commented'
        item['last_error'] = nil
      rescue StandardError => e
        item['last_error'] = "#{e.class}: #{e.message}"
        warn "comment failed #{item['id']}: #{item['last_error']}"
      ensure
        Inventory.write_item(item)
      end
    end
    puts JSON.pretty_generate(comment_due_count: due.size, dry_run: options[:dry_run])
  else
    usage
  end
rescue StandardError => e
  warn "ERROR: #{e.message}"
  exit 1
end
