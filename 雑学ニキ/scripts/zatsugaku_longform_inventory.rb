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
VIDEOS_GLOB = File.join(ROOT, 'metadata/longform/**/video.yaml')
JST = '+09:00'
PUBLISH_SLOT = '06:00'
CATEGORY_KEYS = %w[animal food_drink body_health].freeze
ACTIVE_STATUSES = %w[stock scheduled uploaded].freeze
ALLOWED_STATUSES = (ACTIVE_STATUSES + %w[draft draft_rendered rejected]).freeze
REQUIRED = %w[id category_key status title paths].freeze

class Error < StandardError; end

module LongformInventory
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

  def default_schedule_date
    # Always target a future 06:00 JST slot. After 05:30, choose tomorrow.
    n = now
    n.hour > 5 || (n.hour == 5 && n.min >= 30) ? today.next_day : today
  end

  def timestamp(date)
    Time.new(date.year, date.month, date.day, 6, 0, 0, JST).iso8601
  end

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

  def write_item(item)
    path = item.fetch('_path')
    data = item.reject { |k, _| k.start_with?('_') }
    File.write(path, "# Managed by scripts/zatsugaku_longform_inventory.rb\n" + YAML.dump(data))
  end

  def video_path(item)
    paths = item['paths'] || {}
    paths['video'].to_s
  end

  def contact_sheet_path(item)
    paths = item['paths'] || {}
    paths['contact_sheet'].to_s
  end

  def description(item)
    desc = item['description'].to_s
    return desc unless desc.empty?

    metadata_path = (item['paths'] || {})['metadata'].to_s
    return '' if metadata_path.empty? || !File.file?(metadata_path)

    File.read(metadata_path)
  end

  def visual_audit_complete?(item)
    audit = item['visual_audit']
    return false unless audit.is_a?(Hash)

    audit['contact_sheet_generated'] == true &&
      audit['layout_checked'] == true &&
      audit['no_shorts_reuse'] == true &&
      audit['detail_explanation_cards_present'] == true &&
      audit['intro_only_required_words'] == true &&
      audit['no_outro_prompt'] == true
  end

  def validate_items(items)
    errors = []
    seen_ids = {}
    items.each do |item|
      path = item['_path']
      if item['_parse_error']
        errors << "#{path}: YAML parse error: #{item['_parse_error']}"
        next
      end

      errors << "#{path}: unknown status #{item['status'].inspect}" unless ALLOWED_STATUSES.include?(item['status'])
      errors << "#{path}: missing id" if item['id'].to_s.empty?

      if ACTIVE_STATUSES.include?(item['status'])
        REQUIRED.each do |key|
          value = item[key]
          errors << "#{path}: missing #{key}" if value.nil? || (value.respond_to?(:empty?) && value.empty?)
        end
        errors << "#{path}: unknown category_key #{item['category_key'].inspect}" unless CATEGORY_KEYS.include?(item['category_key'])
        errors << "#{path}: missing description" if description(item).strip.empty?
        errors << "#{path}: video_path not found: #{video_path(item)}" unless File.file?(video_path(item))
        errors << "#{path}: contact_sheet_path not found: #{contact_sheet_path(item)}" unless File.file?(contact_sheet_path(item))
        errors << "#{path}: visual_audit incomplete" unless visual_audit_complete?(item)
      end

      if item['status'] == 'scheduled'
        %w[schedule_date publish_at publish_slot].each do |key|
          errors << "#{path}: scheduled item missing #{key}" if item[key].to_s.empty?
        end
      end
      errors << "#{path}: uploaded item missing video_id" if item['status'] == 'uploaded' && item['video_id'].to_s.empty?

      if item['id']
        errors << "#{path}: duplicate id #{item['id']} also in #{seen_ids[item['id']]}" if seen_ids[item['id']]
        seen_ids[item['id']] = path
      end
    end
    errors
  end

  def logical_publish_date(item)
    return Date.parse(item['schedule_date'].to_s) if item['schedule_date'].to_s != ''
    return nil if item['publish_at'].to_s == ''

    Date.parse(item['publish_at'].to_s[0, 10])
  end

  def planned_for_date?(items, date)
    items.any? { |item| %w[scheduled uploaded].include?(item['status']) && logical_publish_date(item) == date }
  end

  def stock_candidates(items)
    items.select do |item|
      item['status'] == 'stock' && visual_audit_complete?(item) && File.file?(video_path(item))
    end.sort_by { |item| [item['created_at'].to_s, item['id'].to_s] }
  end

  def schedule_next(date:, dry_run:)
    items = load_items
    errors = validate_items(items)
    raise Error, "Validation failed:\n- #{errors.join("\n- ")}" unless errors.empty?
    raise Error, "Longform slot already planned for #{date} 06:00" if planned_for_date?(items, date)

    item = stock_candidates(items).first
    raise Error, 'No usable longform stock found. Create a longform video with status: stock first.' unless item

    item['status'] = 'scheduled'
    item['schedule_date'] = date.to_s
    item['scheduled_at'] = now.iso8601
    item['publish_at'] = timestamp(date)
    item['publish_slot'] = PUBLISH_SLOT
    item['last_error'] = nil
    write_item(item) unless dry_run
    puts JSON.pretty_generate(dry_run: dry_run, selected: item.slice('id', 'category_key', 'title', 'status', 'publish_at', 'publish_slot', '_path'))
  end

  def due_uploads(items)
    items.select do |item|
      item['status'] == 'scheduled' &&
        item['video_id'].to_s.empty? &&
        item['publish_at'].to_s != '' &&
        visual_audit_complete?(item) &&
        File.file?(video_path(item))
    end.sort_by { |item| item['publish_at'].to_s }
  end
end

class YouTubeClient
  TOKEN_URI = URI('https://oauth2.googleapis.com/token')
  UPLOAD_URI = 'https://www.googleapis.com/upload/youtube/v3/videos?uploadType=resumable&part=snippet,status'

  def initialize
    missing = %w[YOUTUBE_CLIENT_ID YOUTUBE_CLIENT_SECRET YOUTUBE_REFRESH_TOKEN].select { |key| ENV[key].to_s.empty? }
    raise Error, "Missing YouTube API credentials: #{missing.join(', ')}" unless missing.empty?

    @client_id = ENV.fetch('YOUTUBE_CLIENT_ID')
    @client_secret = ENV.fetch('YOUTUBE_CLIENT_SECRET')
    @refresh_token = ENV.fetch('YOUTUBE_REFRESH_TOKEN')
  end

  def access_token
    req = Net::HTTP::Post.new(TOKEN_URI)
    req.set_form_data(client_id: @client_id, client_secret: @client_secret, refresh_token: @refresh_token, grant_type: 'refresh_token')
    res = Net::HTTP.start(TOKEN_URI.hostname, TOKEN_URI.port, use_ssl: true) { |http| http.request(req) }
    raise Error, "OAuth refresh failed: HTTP #{res.code} #{res.body}" unless res.is_a?(Net::HTTPSuccess)

    JSON.parse(res.body).fetch('access_token')
  end

  def upload_video(item)
    file = LongformInventory.video_path(item)
    token = access_token
    body = {
      snippet: {
        title: item.fetch('title'),
        description: LongformInventory.description(item),
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
    raise Error, "Upload init failed: HTTP #{init_res.code} #{init_res.body}" unless init_res.is_a?(Net::HTTPRedirection) || init_res.code.to_i == 200

    location = init_res['Location']
    raise Error, 'Upload init failed: missing Location header' if location.to_s.empty?

    upload_uri = URI(location)
    put = Net::HTTP::Put.new(upload_uri)
    put['Authorization'] = "Bearer #{token}"
    put['Content-Type'] = 'video/mp4'
    put.body = File.binread(file)
    put_res = Net::HTTP.start(upload_uri.hostname, upload_uri.port, use_ssl: true) { |http| http.request(put) }
    raise Error, "Upload body failed: HTTP #{put_res.code} #{put_res.body}" unless put_res.is_a?(Net::HTTPSuccess)

    video_id = JSON.parse(put_res.body)['id'].to_s
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
      ruby scripts/zatsugaku_longform_inventory.rb validate
      ruby scripts/zatsugaku_longform_inventory.rb schedule-next [--date YYYY-MM-DD|today|tomorrow] [--dry-run]
      ruby scripts/zatsugaku_longform_inventory.rb upload-due [--dry-run]
  USAGE
  exit 2
end

command = ARGV.shift || usage
options = { date: nil, dry_run: false }
OptionParser.new do |opts|
  opts.on('--date DATE') { |v| options[:date] = v }
  opts.on('--dry-run') { options[:dry_run] = true }
end.parse!(ARGV)

begin
  LongformInventory.load_local_youtube_env

  case command
  when 'validate'
    items = LongformInventory.load_items
    errors = LongformInventory.validate_items(items)
    if errors.empty?
      puts "OK: #{items.size} longform metadata files"
    else
      warn errors.map { |e| "- #{e}" }.join("\n")
      exit 1
    end
  when 'schedule-next'
    date = options[:date] ? LongformInventory.parse_date(options[:date]) : LongformInventory.default_schedule_date
    LongformInventory.schedule_next(date: date, dry_run: options[:dry_run])
  when 'upload-due'
    items = LongformInventory.load_items
    errors = LongformInventory.validate_items(items)
    raise Error, "Validation failed:\n- #{errors.join("\n- ")}" unless errors.empty?

    due = LongformInventory.due_uploads(items)
    client = options[:dry_run] ? nil : YouTubeClient.new
    due.each do |item|
      if options[:dry_run]
        puts "DRY upload #{item['id']} -> #{item['publish_at']}"
        next
      end

      begin
        item['video_id'] = client.upload_video(item)
        item['uploaded_at'] = LongformInventory.now.iso8601
        item['status'] = 'uploaded'
        item['last_error'] = nil
        puts "uploaded #{item['id']} -> #{item['video_id']}"
      rescue StandardError => e
        item['last_error'] = "#{e.class}: #{e.message}"
        warn "upload failed #{item['id']}: #{item['last_error']}"
      ensure
        LongformInventory.write_item(item)
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
