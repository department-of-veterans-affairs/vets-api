require './common-aws-script'

def cc_requests
  data = fetch_data(
    start_date: Date.new(2021, 2, 25),
    end_date: Date.today - 1,
    path: 'logs',
    filter_pattern: request_by_id('4790572a-ce76-4a52-9a52-12e128810629')
  )
  puts "\nProcessing CommunityCareRequest Report"
  #pp data
end

cc_requests