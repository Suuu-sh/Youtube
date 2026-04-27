#!/usr/bin/env ruby
# frozen_string_literal: true

require 'date'
require 'fileutils'
require 'json'
require 'net/http'
require 'optparse'
require 'rexml/document'
require 'time'
require 'uri'

ROOT = File.expand_path('..', __dir__)
JST = '+09:00'

FEEDS = [
  {
    category_key: 'animal',
    category: '動物',
    name: 'ScienceDaily Animals News',
    url: 'https://www.sciencedaily.com/rss/plants_animals/animals.xml'
  },
  {
    category_key: 'food_drink',
    category: '食べ物・飲み物',
    name: 'ScienceDaily Food News',
    url: 'https://www.sciencedaily.com/rss/plants_animals/food.xml'
  },
  {
    category_key: 'body_health',
    category: '人体・健康',
    name: 'CDC Newsroom',
    url: 'https://tools.cdc.gov/api/v2/resources/media/132608.rss'
  },
  {
    category_key: 'science_tech',
    category: '科学・テクノロジー',
    name: 'NIST News',
    url: 'https://www.nist.gov/news-events/news/rss.xml'
  },
  {
    category_key: 'scary_danger',
    category: '怖い・危険',
    name: 'ScienceDaily Natural Disasters News',
    url: 'https://www.sciencedaily.com/rss/earth_climate/natural_disasters.xml'
  }
].freeze

class ScrapeError < StandardError; end

module DailyScrape
  module_function

  def now
    Time.now.getlocal(JST)
  end

  def parse_date(value)
    return Date.parse(now.strftime('%Y-%m-%d')) if value.nil? || value == 'today'
    return Date.parse(now.strftime('%Y-%m-%d')).next_day if value == 'tomorrow'

    Date.parse(value)
  end

  def fetch(url, timeout:)
    uri = URI(url)
    req = Net::HTTP::Get.new(uri)
    req['User-Agent'] = 'zatsugaku-niki-research-bot/1.0 (+local automation)'
    req['Accept'] = 'application/rss+xml, application/atom+xml, application/xml, text/xml, */*'
    res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == 'https', open_timeout: timeout, read_timeout: timeout) do |http|
      http.request(req)
    end
    raise ScrapeError, "HTTP #{res.code} #{res.message}" unless res.is_a?(Net::HTTPSuccess)

    res.body
  end

  def text_at(element, *paths)
    paths.each do |path|
      found = REXML::XPath.first(element, path)
      value = found&.text.to_s.strip
      return value unless value.empty?
    end
    ''
  end

  def atom_link(entry)
    link = REXML::XPath.first(entry, './link[@rel="alternate"]') || REXML::XPath.first(entry, './link')
    link&.attributes&.[]('href').to_s.strip
  end

  def parse_feed(xml)
    doc = REXML::Document.new(xml)
    items = []
    REXML::XPath.each(doc, '//item') do |item|
      items << {
        title: text_at(item, './title'),
        url: text_at(item, './link'),
        published_at: text_at(item, './pubDate', './dc:date'),
        summary: text_at(item, './description')
      }
    end
    REXML::XPath.each(doc, '//*[local-name()="entry"]') do |entry|
      items << {
        title: text_at(entry, './*[local-name()="title"]'),
        url: atom_link(entry),
        published_at: text_at(entry, './*[local-name()="updated"]', './*[local-name()="published"]'),
        summary: text_at(entry, './*[local-name()="summary"]', './*[local-name()="content"]')
      }
    end
    items.map { |item| clean_item(item) }.reject { |item| item[:title].empty? || item[:url].empty? }
  end

  def clean_item(item)
    item.transform_values do |value|
      value.to_s.gsub(/<[^>]+>/, ' ').gsub(/\s+/, ' ').strip
    end
  end

  def recent_items(items, limit:)
    items.sort_by { |item| parse_time(item[:published_at]) || Time.at(0) }.reverse.first(limit)
  end

  def parse_time(value)
    Time.parse(value.to_s)
  rescue ArgumentError
    nil
  end

  def collect(limit:, timeout:)
    FEEDS.map do |feed|
      begin
        xml = fetch(feed[:url], timeout: timeout)
        items = recent_items(parse_feed(xml), limit: limit)
        feed.merge(status: 'ok', items: items)
      rescue StandardError => e
        feed.merge(status: 'error', error: "#{e.class}: #{e.message}", items: [])
      end
    end
  end

  def write_report(target_date:, results:, dry_run:)
    out_dir = File.join(ROOT, 'research', 'daily')
    FileUtils.mkdir_p(out_dir) unless dry_run
    date = target_date.to_s
    json_path = File.join(out_dir, "#{date}.json")
    md_path = File.join(out_dir, "#{date}.md")
    payload = {
      target_date: date,
      collected_at: now.iso8601,
      feeds: results
    }

    markdown = +"# 雑学ニキ daily research #{date}\n\n"
    markdown << "- collected_at: #{payload[:collected_at]}\n"
    markdown << "- purpose: 04:00 automation の動画作成前リサーチ素材\n\n"
    results.each do |feed|
      markdown << "## #{feed[:category]} / #{feed[:name]}\n\n"
      if feed[:status] != 'ok'
        markdown << "- status: error\n"
        markdown << "- error: #{feed[:error]}\n\n"
        next
      end
      if feed[:items].empty?
        markdown << "- status: ok, but no items parsed\n\n"
        next
      end
      feed[:items].each_with_index do |item, index|
        markdown << "#{index + 1}. #{item[:title]}\n"
        markdown << "   - url: #{item[:url]}\n"
        markdown << "   - published_at: #{item[:published_at]}\n" unless item[:published_at].empty?
        markdown << "   - memo: #{item[:summary][0, 180]}\n" unless item[:summary].empty?
      end
      markdown << "\n"
    end

    unless dry_run
      File.write(json_path, JSON.pretty_generate(payload))
      File.write(md_path, markdown)
    end

    {
      dry_run: dry_run,
      target_date: date,
      markdown_path: md_path,
      json_path: json_path,
      feed_count: results.size,
      error_count: results.count { |feed| feed[:status] != 'ok' },
      item_count: results.sum { |feed| feed[:items].size }
    }
  end
end

if $PROGRAM_NAME == __FILE__
  options = { date: 'tomorrow', limit: 5, timeout: 12, dry_run: false }
  OptionParser.new do |opts|
    opts.on('--date DATE') { |value| options[:date] = value }
    opts.on('--limit N', Integer) { |value| options[:limit] = value }
    opts.on('--timeout SECONDS', Integer) { |value| options[:timeout] = value }
    opts.on('--dry-run') { options[:dry_run] = true }
  end.parse!(ARGV)

  begin
    target_date = DailyScrape.parse_date(options[:date])
    results = DailyScrape.collect(limit: options[:limit], timeout: options[:timeout])
    summary = DailyScrape.write_report(target_date: target_date, results: results, dry_run: options[:dry_run])
    puts JSON.pretty_generate(summary)
  rescue StandardError => e
    warn "ERROR: #{e.message}"
    exit 1
  end
end
