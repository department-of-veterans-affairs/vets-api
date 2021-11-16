# frozen_string_literal: true

require 'date'
require 'digest'
require 'open3'
require 'time'
require 'json'
require 'pp'
require 'pry'
require 'net/http'
require 'uri'
require 'csv'

AWS_LOG_PATH = 'dsva-vagov-prod/srv/vets-api/src/log/vets-api-server.log'

class LogsProcessor
  def request_by_id(id)
    "{$.named_tags.request_id=\"#{id}\"}"
  end

  def self.fetch_data(options)
    ranges(options[:start_date], options[:end_date]).each do |range|
      command = "awslogs get #{AWS_LOG_PATH} \
                 -s '#{range[0].shellescape}' \
                 -e '#{range[1].shellescape}' \
                 -f '#{options[:filter_pattern].shellescape}'"
      puts "Executing #{command}"
      Open3.popen3 command do |_stdin, stdout, stderr, _wait_thr|
        stdout_str = stdout.read
        stderr_str = stderr.read

        stdout_arr = stdout_str.split(%r{dsva-vagov-prod/srv/vets-api/src/log/vets-api-server.log[^|]+\| })
        stdout_arr = stdout_arr[1..]

        puts stderr_str if stderr_str

        stdout_arr.each do |log|
          log = data_scrub(log)
          json_log = JSON.parse(log)
          yield json_log # Yield control to the calling block
        end
      end
    end
  end

  def self.ranges(start_date, end_date)
    (start_date..end_date).map do |day|
      if $DEBUG
        [day.to_datetime.iso8601, DateTime.new(day.year, day.month, day.day, 0, 5, 59, 0).iso8601]
      else
        [day.to_datetime.iso8601, DateTime.new(day.year, day.month, day.day, 23, 59, 59, 0).iso8601]
      end
    end
  end

  def self.data_scrub(string)
    string.gsub(%r{/ICN/\S+/}, '/ICN/REDACTED_ICN/')
          .gsub(%r{/appointments/v1/patients/\S+/}, '/appointments/v1/patients/REDACTED_ICN/')
  end
end
