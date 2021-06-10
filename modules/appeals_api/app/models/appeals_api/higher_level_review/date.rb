# frozen_string_literal: true

module AppealsApi
  class HigherLevelReview::Date
    def initialize(date)
      @raw_date = date
      @date = date_from_string(date)
    end

    def day
      date.strftime('%d')
    end

    def month
      date.strftime('%m')
    end

    def year
      date.strftime('%Y')
    end

    def formatted_date(formatter: '/')
      "#{month}#{formatter}#{day}#{formatter}#{year}"
    end

    def in_the_past?
      date < Time.zone.today
    end

    attr_reader :raw_date

    def valid?
      !!date
    end

    private

    attr_reader :date

    def date_from_string(date)
      return date.to_date if time?

      date.match(/\d{4}-\d{2}-\d{2}/) && Date.parse(date)
    rescue ArgumentError
      nil
    end

    def time?
      raw_date.instance_of?(Time) || raw_date.instance_of?(ActiveSupport::TimeWithZone)
    end
  end
end
