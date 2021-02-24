require './common-aws-script'

def appointment_requests
  data = fetch_data(
    start_date: Date.new(2020, 9, 28),
    end_date: Date.today - 1,
    path: 'logs',
    filter_pattern: '{ $.message = "VAOS AppointmentRequest" }'
  )
  puts "\nProcessing AppointmentRequest Report"
  pp data
end

appointment_requests