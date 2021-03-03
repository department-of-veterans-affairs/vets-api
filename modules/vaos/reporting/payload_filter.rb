require './logs_processor'
require './redis_service'

class PayloadFilter
  def initialize(name, tag, pattern, options)
    @name = name
    @tag = tag
    @pattern = pattern
    @options = options
  end
  def fetch
    puts "#{@name}\n"

    @options.merge!(
      {filter_pattern: "{($.payload.url='*#{@pattern}*')}"},
      {path: 'logs'}
    ) 
   
    LogsProcessor.fetch_data(@options) do |json_log|
      request_id = json_log['named_tags']['request_id']
      http_status = json_log['payload']['status']
      timestamp = DateTime.parse(json_log['timestamp'])
      save("#{@tag}:#{timestamp.strftime("%Y%m%d%H%M%S")}:#{http_status}:#{request_id}", json_log)
    end
  end
end