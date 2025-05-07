# frozen_string_literal: true

module Utilities
  class DateParser
    class << self
      def parse(date)
        return nil if date.blank?
        return date if date.is_a?(DateTime)
        return date.to_datetime if date.is_a?(Time)

        if date.is_a?(Hash) && date['year'] && date['month'] && date['day']
          # For hash format, use current time components since we only have date
          now = Time.now.utc
          return DateTime.new(date['year'].to_i, date['month'].to_i, date['day'].to_i, now.hour, now.min, now.sec)
        end

        if date.is_a?(Date)
          now = Time.now.utc
          return DateTime.new(date.year, date.month, date.day, now.hour, now.min, now.sec)
        end

        # Try parsing as string
        DateTime.parse(date.to_s)
      rescue => e
        Rails.logger.error("Error parsing submit date: #{date}, error: #{e.message}")
        nil
      end
    end
  end
end
