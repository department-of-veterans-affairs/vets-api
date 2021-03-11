# frozen_string_literal: true

# Given a date to format, in either a Date/Time object, or a String representing a Date,
# additionally an optional symbol from config/initializers/date_formats.rb to specifically
# format. Default is  Date object :iso8601, or '2020-01-31'
module Formatters
  class DateFormatter
    def self.format_date(date_to_format, format = :iso8601)
      return if date_to_format.nil?

      begin
        Date.parse(date_to_format.to_s).to_s(format)
      rescue ArgumentError
        Rails.logger.error "[Formatters/DateFormatter] Cannot parse given date: #{date_to_format}"
        nil
      end
    end
  end
end
