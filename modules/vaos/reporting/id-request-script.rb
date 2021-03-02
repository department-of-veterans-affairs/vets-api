require './common-aws-script'

def cc_requests
  data = fetch_data(
    start_date: Date.new(2021, 2, 28),
    end_date: Date.today - 1,
    path: 'logs',
    filter_pattern: request_by_id('a8d9e139-65bd-4c30-88b7-1470c167799d')
  )
  puts "\nProcessing CommunityCareRequest Report"
  #pp data
end

cc_requests