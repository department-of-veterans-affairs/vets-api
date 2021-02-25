require './common-aws-script'

def cc_requests
  data = fetch_data(
    start_date: Date.new(2021, 2, 24),
    end_date: Date.today - 1,
    path: 'logs',
    filter_pattern: '{($.payload.url="*booked-cc-appointments*") && ($.named_tags.request_id="*")}'
  )
  puts "\nProcessing CommunityCareRequest Report"
  #pp data
  #store_data_to_redis(data)
end

def store_data_to_redis(data)
  data.each do |log|
    save(log[:key], log)
  end
end

cc_requests

# save("a", 1)
# puts "Retrieved redis value: " + load("a")
