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
GLOB = File.join(ROOT, 'metadata/specific/animal/**/series.yaml')
JST = '+09:00'
PUBLISH_SLOT = '21:00'
REQUIRED = %w[id series_key category category_key topic_key status video_path contact_sheet_path title description used_animal visual_audit].freeze
ACTIVE_STATUSES = %w[scheduled uploaded].freeze

class Error < StandardError; end

module SpecificInventory
  module_function

  def now
    Time.now.getlocal(JST)
  end

  def load_items
    Dir.glob(GLOB).sort.map do |path|
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
    when Hash then obj.each_with_object({}) { |(k, v), h| h[k.to_s] = stringify_keys(v) }
    when Array then obj.map { |v| stringify_keys(v) }
    else obj
    end
  end

  def write_item(item)
    path = item.fetch('_path')
    data = item.reject { |k, _| k.start_with?('_') }
    File.write(path, "# Managed by scripts/zatsugaku_specific_inventory.rb\n" + YAML.dump(data))
  end

  def detail_description?(text)
    text.to_s.include?('【詳細・補足】') && text.to_s.each_line.count { |line| line.match?(/^\s*\d+\./) } >= 5
  end

  def visual_audit_complete?(item)
    audit = item['visual_audit']
    audit.is_a?(Hash) && %w[contact_sheet_checked image_subject_match_checked no_unrelated_placeholder_images no_excessive_reuse].all? { |k| audit[k] == true } && audit['checked_at'].to_s != '' && audit['notes'].to_s != ''
  end

  def validate_items(items)
    errors = []
    seen_animals = {}
    items.each do |item|
      path = item['_path']
      if item['_parse_error']
        errors << "#{path}: YAML parse error: #{item['_parse_error']}"
        next
      end
      REQUIRED.each { |key| errors << "#{path}: missing #{key}" if item[key].nil? || (item[key].respond_to?(:empty?) && item[key].empty?) }
      errors << "#{path}: series_key must be specific_animal" unless item['series_key'] == 'specific_animal'
      errors << "#{path}: category_key must be animal" unless item['category_key'] == 'animal'
      errors << "#{path}: publish_slot must be 21:00" if ACTIVE_STATUSES.include?(item['status']) && item['publish_slot'].to_s != PUBLISH_SLOT
      errors << "#{path}: description must include detailed numbered notes" if ACTIVE_STATUSES.include?(item['status']) && !detail_description?(item['description'])
      errors << "#{path}: visual_audit incomplete" if ACTIVE_STATUSES.include?(item['status']) && !visual_audit_complete?(item)
      errors << "#{path}: video_path not found" if item['video_path'].to_s != '' && !File.exist?(item['video_path'].to_s)
      errors << "#{path}: contact_sheet_path not found" if item['contact_sheet_path'].to_s != '' && !File.exist?(item['contact_sheet_path'].to_s)
      animal = item['used_animal'].to_s.downcase
      if animal != ''
        errors << "#{path}: duplicate used_animal #{animal} also in #{seen_animals[animal]}" if seen_animals[animal]
        seen_animals[animal] = path
      end
    end
    errors
  end

  def next_missing_date(items, from: Date.parse(now.strftime('%Y-%m-%d')), horizon_days: 60)
    (0...horizon_days).each do |offset|
      d = from + offset
      publish_at = Time.new(d.year, d.month, d.day, 21, 0, 0, JST)
      next if publish_at < now
      used = items.any? do |item|
        %w[scheduled uploaded].include?(item['status']) && (item['schedule_date'].to_s == d.to_s || item['publish_at'].to_s.start_with?(d.to_s))
      end
      return d unless used
    end
    nil
  end

  def due_uploads(items)
    items.select do |item|
      item['status'] == 'scheduled' && item['video_id'].to_s.empty? && item['publish_at'].to_s != '' && visual_audit_complete?(item) && File.exist?(item['video_path'].to_s)
    end.sort_by { |i| i['publish_at'].to_s }
  end
end

class YouTubeClient
  TOKEN_URI = URI('https://oauth2.googleapis.com/token')
  UPLOAD_URI = 'https://www.googleapis.com/upload/youtube/v3/videos?uploadType=resumable&part=snippet,status'
  RETRYABLE_NETWORK_ERRORS = [
    EOFError,
    IOError,
    Net::OpenTimeout,
    Net::ReadTimeout,
    SocketError,
    SystemCallError
  ].freeze

  def initialize
    load_env
    missing = %w[YOUTUBE_CLIENT_ID YOUTUBE_CLIENT_SECRET YOUTUBE_REFRESH_TOKEN].select { |key| ENV[key].to_s.empty? }
    raise Error, "Missing YouTube API credentials: #{missing.join(', ')}" unless missing.empty?
  end

  def load_env
    path = ENV.fetch('ZATSUGAKU_YOUTUBE_ENV', '/Users/yota/.codex/secrets/youtube_zatsugaku_api.env')
    return unless File.file?(path)
    File.foreach(path) do |line|
      line = line.strip
      next if line.empty? || line.start_with?('#')
      k, v = line.split('=', 2)
      ENV[k] ||= v.to_s.strip.sub(/\A(['"])(.*)\1\z/, '\\2')
    end
  end

  def access_token
    req = Net::HTTP::Post.new(TOKEN_URI)
    req.set_form_data(client_id: ENV.fetch('YOUTUBE_CLIENT_ID'), client_secret: ENV.fetch('YOUTUBE_CLIENT_SECRET'), refresh_token: ENV.fetch('YOUTUBE_REFRESH_TOKEN'), grant_type: 'refresh_token')
    res = request_with_retries(TOKEN_URI, req, label: 'OAuth refresh', read_timeout: 30) { |r| r.is_a?(Net::HTTPSuccess) }
    raise Error, "OAuth refresh failed: HTTP #{res.code} #{res.body}" unless res.is_a?(Net::HTTPSuccess)
    JSON.parse(res.body).fetch('access_token')
  end

  def upload_video(item)
    token = access_token
    file = item.fetch('video_path')
    body = { snippet: { title: item.fetch('title'), description: item.fetch('description'), categoryId: '22' }, status: { privacyStatus: 'private', publishAt: Time.parse(item.fetch('publish_at')).utc.iso8601, selfDeclaredMadeForKids: false } }.to_json
    uri = URI(UPLOAD_URI)
    init = Net::HTTP::Post.new(uri)
    init['Authorization'] = "Bearer #{token}"
    init['Content-Type'] = 'application/json; charset=UTF-8'
    init['X-Upload-Content-Type'] = 'video/mp4'
    init['X-Upload-Content-Length'] = File.size(file).to_s
    init.body = body
    init_res = request_with_retries(uri, init, label: 'YouTube upload init', read_timeout: 60) { |r| r.is_a?(Net::HTTPRedirection) || r.code.to_i == 200 }
    raise Error, "Upload init failed: HTTP #{init_res.code} #{init_res.body}" unless init_res.is_a?(Net::HTTPRedirection) || init_res.code.to_i == 200
    location = init_res['Location']
    raise Error, 'Upload init failed: missing Location header' if location.to_s.empty?
    upload_uri = URI(location)
    put = Net::HTTP::Put.new(upload_uri)
    put['Authorization'] = "Bearer #{token}"
    put['Content-Type'] = 'video/mp4'
    put.body = File.binread(file)
    put_res = request_with_retries(upload_uri, put, label: 'YouTube upload body', read_timeout: 180) { |r| r.is_a?(Net::HTTPSuccess) }
    raise Error, "Upload body failed: HTTP #{put_res.code} #{put_res.body}" unless put_res.is_a?(Net::HTTPSuccess)
    JSON.parse(put_res.body).fetch('id')
  end

  def request_with_retries(uri, request, label:, read_timeout:)
    attempts = Integer(ENV.fetch('ZATSUGAKU_UPLOAD_RETRY_ATTEMPTS', '3'))
    base_sleep = Float(ENV.fetch('ZATSUGAKU_UPLOAD_RETRY_BASE_SLEEP', '5'))
    attempts = 1 if attempts < 1

    (1..attempts).each do |attempt|
      begin
        response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == 'https', open_timeout: 20, read_timeout: read_timeout) { |http| http.request(request) }
        return response if yield(response)
        return response unless retryable_http_response?(response) && attempt < attempts

        warn "#{label} retry #{attempt + 1}/#{attempts}: HTTP #{response.code}"
      rescue *RETRYABLE_NETWORK_ERRORS => e
        raise if attempt >= attempts

        warn "#{label} retry #{attempt + 1}/#{attempts}: #{e.class}: #{e.message}"
      end
      sleep(base_sleep * attempt)
    end
  end

  def retryable_http_response?(response)
    code = response.code.to_i
    code == 408 || code == 429 || code.between?(500, 599)
  end
end

command = ARGV.shift || 'validate'
opts = { dry_run: false }
OptionParser.new { |o| o.on('--dry-run') { opts[:dry_run] = true } }.parse!(ARGV)
items = SpecificInventory.load_items
errors = SpecificInventory.validate_items(items)
case command
when 'validate'
  if errors.empty? then puts "OK: #{items.size} specific animal metadata files" else warn errors.map { |e| "- #{e}" }.join("\n"); exit 1 end
when 'next-missing-date'
  raise Error, "Validation failed:\n- #{errors.join("\n- ")}" unless errors.empty?
  d = SpecificInventory.next_missing_date(items)
  puts JSON.pretty_generate(date: d&.to_s, publish_slot: PUBLISH_SLOT)
when 'upload-due'
  raise Error, "Validation failed:\n- #{errors.join("\n- ")}" unless errors.empty?
  due = SpecificInventory.due_uploads(items)
  client = opts[:dry_run] ? nil : YouTubeClient.new
  due.each do |item|
    if opts[:dry_run]
      puts "DRY upload #{item['id']} -> #{item['publish_at']}"
      next
    end
    begin
      item['video_id'] = client.upload_video(item)
      item['uploaded_at'] = SpecificInventory.now.iso8601
      item['status'] = 'uploaded'
      item['last_error'] = nil
      puts "uploaded #{item['id']} -> #{item['video_id']}"
    rescue StandardError => e
      item['last_error'] = "#{e.class}: #{e.message}"
      warn "upload failed #{item['id']}: #{item['last_error']}"
    ensure
      SpecificInventory.write_item(item)
    end
  end
  puts JSON.pretty_generate(upload_due_count: due.size, dry_run: opts[:dry_run])
else
  raise Error, "Unknown command: #{command}"
end
