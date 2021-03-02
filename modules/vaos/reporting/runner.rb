require './payload_filter'

class Runner
  def initialize(
    start_date = Date.new(2021, 2, 25),
    end_date = Date.today - 1,
    pattern
  )
    options = {
      start_date: start_date,
      end_date: end_date,
      path: 'logs',
      filter_pattern: "{($.payload.url='*#{pattern}*')}"
    }
    payload_filter = PayloadFilter.new('Booked CC Appointments', 'bookedccappts', options)
    payload_filter.fetch
  end
end

Runner.new(ARGV[0])