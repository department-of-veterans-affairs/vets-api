require './common-aws-script'
require './redis_service'

# todo: put payload filter back in the class

class PayloadFilter
  def initialize(name, tag, options)
    @name = name
    @tag = tag
    @options = options
  end
  def fetch
    puts "#{@name}\n"

    LogsProcessor.fetch_data(@options) do |json_log|
      save("#{@tag}:#{Time.now.strftime("%Y%m%d")}:#{json_log['named_tags']['request_id']}", json_log)
    end
  end
end