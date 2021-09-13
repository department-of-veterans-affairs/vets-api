# frozen_string_literal: true

class DownTimeChecker
  DOWNTIME_WINDOWS = [
    ['Tuesday at 2am UTC', 'Tuesday at 10am UTC'],
    ['Wednesday at 2am UTC', 'Wednesday at 10am UTC'],
    ['Thursday at 2am UTC', 'Thursday at 10am UTC'],
    ['Friday at 2am UTC', 'Friday at 10am UTC'],
    ['Saturday at 2am UTC', 'Saturday at 10am UTC']
  ].freeze

  def initialize(service)
    @service = service[:service_name]
    @extra_delay = service[:extra_delay]
  end

  def down?
    if DOWNTIME_WINDOWS.any? { |w| (parse_time(w[0])..parse_time(w[1])).cover?(Time.now.utc) }
      (Time.zone.parse('Today at 10am UTC') - Time.zone.now) + @extra_delay
    else
      false
    end
  end

  private

  def parse_time(str)
    Time.zone.parse(str)
  end
end
