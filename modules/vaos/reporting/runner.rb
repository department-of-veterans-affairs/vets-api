require './logs_processor'
require './redis_service'

$DEBUG=false

def fetch(filter, options)
  options.merge!(
    {filter_pattern: filter},
    {path: 'logs'}
  ) 

  LogsProcessor.fetch_data(options) do |json_log|
    request_id = json_log['named_tags']['request_id']
    http_method = /\(.*\)/.match(json_log['payload']['url'])[0][1..-2]
    http_status = json_log['payload']['status']
    timestamp = DateTime.parse(json_log['timestamp'])
    endpoint = /(\/)((?!.*\/).*)(\?)|(\/)((?!.*\/)).*/.match(json_log['payload']['url'])[0]
    tag = endpoint[-1] == '?' ? endpoint[1..-2] : endpoint[1..-1]
    key = "#{tag}:#{timestamp.strftime("%Y%m%d%H%M%S")}:#{http_method}:#{http_status}:#{request_id}"

    puts key unless !$DEBUG
    if (!$DEBUG)
      save key, json_log
    end
  end
end

def runner(
  filter,
  start_date,
  end_date
)

  start_date = start_date ? Date.parse(start_date) : Date.today
  end_date = (start_date && end_date) ? Date.parse(end_date) : Date.today
  
  options = {
    start_date: start_date,
    end_date: end_date,
  }

  fetch filter, options
end

runner(ARGV[0], ARGV[1], ARGV[2])