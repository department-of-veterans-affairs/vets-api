require './common-aws-script'

def cc_requests
  data = fetch_data(
    start_date: Date.new(2020, 9, 28),
    end_date: Date.today - 1,
    path: 'logs',
    filter_pattern: '{$.payload.url="*booked-cc-appointments*"}'
  )
  puts "\nProcessing CommunityCareRequest Report"
  pp data
end

cc_requests
