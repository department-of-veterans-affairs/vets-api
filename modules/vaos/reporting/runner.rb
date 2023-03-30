#!/usr/bin/env ruby
# frozen_string_literal: true

require 'optparse'
require 'active_support/all'
require './logs_processor'
require './redis_service'

# runner.rb debugging flag
$DEBUG = false

#
# this class handles command line parsing.
class RunnerOptions < Hash
  def initialize(args)
    super()
    self[:show_ends] = ''
    options = get_options
    options.parse!(args)
  end

  def get_options
    OptionParser.new do |opts|
      @opts = opts
      opts.banner = 'Usage: runner.rb [options]'
      opts.on('-s', '--start-date <yyyy-mm-dd>', 'Date to start search on.') do |date|
        self[:sdt] = date
      end
      opts.on('-e', '--end-date <yyyy-mm-dd>', 'Date to end search on, inclusive.',
              ' Optional: defaults to current date.') do |date|
        self[:edt] = date
      end
      opts.on('-f', '--filter-pattern <pattern>', 'CloudWatch log filter pattern.',
              ' Optional: defaults to {($.message="VAOS*") && ($.payload.url="*")}') do |filter_pattern|
        self[:fp] = filter_pattern
      end
      opts.on_tail('-h', '--help', 'Display help message.') do
        usage
        exit
      end
    end
  end

  def usage
    puts "\n  #{@opts}"
  end
end

#
# parse the runner.rb command line options
begin
  arguments = RunnerOptions.new(ARGV)
rescue OptionParser::InvalidOption, OptionParser::MissingArgument => e
  puts "\nUnable to parse arguments => #{e.message}\n"
  exit 1
end

#
# extract individual options...
# start date
begin
  start_date = if arguments[:sdt].nil?
                 Time.current.to_date - 1
               else
                 Date.parse(arguments[:sdt])
               end
rescue ArgumentError
  puts "\nUnable to parse start date #{arguments[:sdt]}"
  exit 1
end

# end date
begin
  end_date = if arguments[:edt].nil?
               Time.current.to_date
             else
               Date.parse(arguments[:edt])
             end
rescue ArgumentError
  puts "\nUnable to parse end date #{arguments[:edt]}"
  exit 1
end

# filter pattern
filter_pattern = if arguments[:fp].nil?
                   '{($.message="VAOS*") && ($.payload.url="*")}'
                 else
                   arguments[:fp]
                 end

#
# query CloudWatch and store in records in Redis
options = { filter_pattern:,
            start_date:,
            end_date: }

LogsProcessor.fetch_data(options) do |json_log|
  request_id = json_log['named_tags']['request_id']
  http_method = /\(.*\)/.match(json_log['payload']['url'])[0][1..-2]
  http_status = json_log['payload']['status']
  timestamp = DateTime.parse(json_log['timestamp'])
  endpoint = %r{(/)((?!.*/).*)(\?)|(/)((?!.*/)).*}.match(json_log['payload']['url'])[0]
  tag = endpoint[-1] == '?' ? endpoint[1..-2] : endpoint[1..]
  key = "#{tag}:#{timestamp.strftime('%Y%m%d%H%M%S')}:#{http_method}:#{http_status}:#{request_id}"

  puts key if $DEBUG
  save(key, json_log) unless $DEBUG
end
