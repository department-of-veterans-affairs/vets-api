# frozen_string_literal: true

class DownTimeChecker
  DOWNTIME_WINDOWS = [
    { begin: 'Tuesday at 2am UTC', end: 'Tuesday at 10am UTC' },
    { begin: 'Wednesday at 2am UTC', end: 'Wednesday at 10am UTC' },
    { begin: 'Thursday at 2am UTC', end: 'Thursday at 10am UTC' },
    { begin: 'Friday at 2am UTC', end: 'Friday at 10am UTC' },
    { begin: 'Saturday at 2am UTC', end: 'Saturday at 10am UTC' }
  ].freeze

  def initialize(service)
    @service_name = service[:service_name]
    @extra_delay = service[:extra_delay]
  end

  def down?
    if within_downtime_window?
      time_until_up + @extra_delay
    else
      false
    end
  end

  private

  def parse_time(str)
    Time.zone.parse(str)
  end

  def within_downtime_window?
    DOWNTIME_WINDOWS.any? do |window|
      window = downtime_window window
      window.cover? Time.now.utc
    end
  end

  def downtime_window(begin_end_time)
    begin_time = Time.zone.parse begin_end_time[:begin]
    end_time = Time.zone.parse begin_end_time[:end]

    begin_time..end_time
  end

  def time_until_up
    Time.zone.parse('Today at 10am UTC') - Time.zone.now
  end
end
