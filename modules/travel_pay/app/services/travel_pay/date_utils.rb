# frozen_string_literal: true

module TravelPay
  module DateUtils
    def self.strip_timezone(time)
      # take the time and parse it as a Time object if necessary
      # convert it to an array of its parts - zone will be nil
      # create a new time with those parts, using the nil timezone
      t = try_parse_date(time)
      time_parts = %i[year month day hour min sec]
      Time.utc(*t.deconstruct_keys(time_parts).values)
    end

    def self.try_parse_date(datetime)
      raise InvalidComparableError.new('Provided datetime is nil.', datetime) if datetime.nil?

      return datetime.to_time if datetime.is_a?(Time) || datetime.is_a?(Date)

      # Disabled Rails/Timezone rule because we don't care about the tz in this dojo.
      # If we parse it any other 'recommended' way, the time will be converted based
      # on the timezone, and the datetimes won't match
      Time.parse(datetime) if datetime.is_a? String # rubocop:disable Rails/TimeZone
    end

    def self.try_parse_date_range(start_date, end_date)
      unless start_date && end_date
        raise ArgumentError,
              message: "Both start and end dates are required, got #{start_date}-#{end_date}."
      end

      { start_date: try_parse_date(start_date), end_date: try_parse_date(end_date) }
    end
  end
end
