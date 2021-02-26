require 'date'
require 'digest'
require 'open3'
require 'time'
require 'json'
require 'pp'
require 'digest'
require 'pry'
require 'net/http'
require 'uri'
require 'csv'

require './redis-test'

AWS_LOG_PATH = "dsva-vagov-prod/srv/vets-api/src/log/vets-api-server.log"

# In the future we can use OptionsParser to make this accept arguments
DEFAULT_OPTIONS = {
  start_date: Date.new(2020, 9, 28),
  end_date: Date.today - 1,
  filter_pattern:  '{ ($.message = “VAOS service call*“) }',
  path: 'logs'
}

def request_by_id(id)
  "{$.named_tags.request_id=\"#{id}\"}"
end

def ranges(start_date, end_date)
  (start_date..end_date).map do |day|
    [day.to_datetime.iso8601, DateTime.new(day.year, day.month, day.day, 00, 04, 59, 0).iso8601]
  end
end

def filter_pattern_hash(options)
  Digest::MD5.hexdigest(options[:filter_pattern])[0..6]
end

def fetch_data(options)
  ranges(options[:start_date], options[:end_date]).each do |range|
    Dir.mkdir(options[:path]) unless File.exists?(options[:path])
    path = "#{options[:path]}/#{range[0].split('T00').first}.#{filter_pattern_hash(options)}.vaos.log"
    # If logs were previously fetched for the current day, they are likely stale and should be fetched again.
    #   in the future could figure out a way to append to the existing file.
    # File.delete(path) if DateTime.parse(range[1]).to_date == Date.today && File.exist?(path)
    if File.exist?(path)
      puts "Logs already exist at #{path}. Using Existing Logs."
    else
      puts "Fetching logs from Cloudwatch > #{path}"
      command = "awslogs get #{AWS_LOG_PATH} -s '#{range[0]}' -e '#{range[1]}' -f '#{options[:filter_pattern]}'"
      puts "Executing #{command}"
      Open3.popen3 command do |stdin, stdout, stderr, wait_thr|
        stdout_str = stdout.read
        stderr_str = stderr.read
        status = wait_thr.value

        stdout_arr = stdout_str.split(/dsva-vagov-prod\/srv\/vets-api\/src\/log\/vets-api-server.log[^|]+\| /)
        stdout_arr = stdout_arr[1..-1]
        puts stdout_arr

        stdout_arr.each do |log|
          json_log = JSON.parse(log)
          save(json_log['named_tags']['request_id'], json_log)
        end

        if status.success?
          File.open(path, 'w') do |file|
            file.write stdout_str
          end
        else
          puts 'Error occurred fetching data for ' + path
          puts stderr_str
          exit status.exitstatus
        end
      end
    end
  end
  json_data(options)
end

def json_data(options)
  ranges(options[:start_date], options[:end_date]).map do |range|
    path = "#{options[:path]}/#{range[0].split('T00').first}.#{filter_pattern_hash(options)}.vaos.log"
    File.open(path).each_line.map do |line|
      group, stream, broken_body = line.split(" ", 3)
      body = broken_body.split('| ')[1]
      json = JSON.parse(data_scrub(body))
      json["payload"].merge("timestamp" => json["timestamp"]) # .merge(json["named_tags"]) Excluded for now since it includes remote ip
    end
  end.flatten
end

def data_scrub(string)
  string.gsub(/\/ICN\/\S+\//, '/ICN/REDACTED_ICN/')
        .gsub(/\/appointments\/v1\/patients\/\S+\//, '/appointments/v1/patients/REDACTED_ICN/')
end
