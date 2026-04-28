#!/usr/bin/env ruby
# frozen_string_literal: true

require 'date'
require 'json'
require 'optparse'
require 'yaml'

ROOT = File.expand_path('..', __dir__)
VIDEOS_GLOB = File.join(ROOT, 'metadata/stock/**/stock.yaml')
JST = '+09:00'

CATEGORY_SCHEDULE = [
  { key: 'animal', name: '動物' },
  { key: 'food_drink', name: '食べ物・飲み物' },
  { key: 'body_health', name: '人体・健康' },
  { key: 'science_tech', name: '科学・テクノロジー' },
  { key: 'scary_danger', name: '怖い・危険' }
].freeze

CATEGORY_KEYS = CATEGORY_SCHEDULE.map { |category| category[:key] }.freeze
REQUIRED = %w[id category category_key level topic_key fact_summary status video_path title description].freeze
ACTIVE_STATUSES = %w[stock uploaded].freeze
ALLOWED_STATUSES = (ACTIVE_STATUSES + %w[rejected]).freeze
DESCRIPTION_DETAIL_HEADING = '【詳細・補足】'
DETAIL_NUMBER_RE = /^\s*\d+\./
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
end

def usage
  warn <<~USAGE
    Usage:
      ruby scripts/zatsugaku_inventory.rb validate
      ruby scripts/zatsugaku_inventory.rb next-missing-set [--date YYYY-MM-DD|today] [--horizon-days N]
      ruby scripts/zatsugaku_inventory.rb overlap-report [--category KEY] [--level LvN] [--min-overlap N] [--strict]
  USAGE
  exit 2
end

command = ARGV.shift || usage
options = { date: 'today', horizon_days: 31, category: nil, level: nil, min_overlap: DEFAULT_TOPIC_OVERLAP_MIN, strict: false }
OptionParser.new do |opts|
  opts.on('--date DATE') { |v| options[:date] = v }
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
  else
    usage
  end
rescue StandardError => e
  warn "ERROR: #{e.message}"
  exit 1
end
