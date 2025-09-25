# frozen_string_literal: true

require 'date'

module ClaimsApi
  class PartialDateParser
    FORMATS = %w[%Y %Y-%m %Y-%m-%d %m-%Y %m-%d-%Y].freeze
    def self.to_fes(string_date) # rubocop:disable Metrics/MethodLength
      input = string_date.to_s.strip
      return nil if input.empty?

      FORMATS.each do |format_date|
        begin
          date_formatted = Date.strptime(input, format_date)
        rescue ArgumentError
          next
        end
        next unless date_formatted.strftime(format_date) == input

        case format_date
        when '%Y'
          return { year: date_formatted.year }
        when '%Y-%m', '%m-%Y'
          return { year: date_formatted.year, month: date_formatted.month }
        when '%Y-%m-%d', '%m-%d-%Y'
          return { year: date_formatted.year, month: date_formatted.month, day: date_formatted.day }
        else
          next
        end
      end
      nil
    end
  end
end
