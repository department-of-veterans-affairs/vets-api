# frozen_string_literal: true

require 'date'

module ClaimsApi
  class PartialDateParser
    FORMATS = %w[%Y-%m-%d %m-%d-%Y %Y-%m %m-%Y %Y].freeze

    def self.to_fes(string_date) # rubocop:disable Metrics/MethodLength
      input = string_date.to_s.strip
      return nil if input.empty?

      FORMATS.each do |format_date|
        dated_formatted = Date._strptime(input, format_date)
        next unless dated_formatted && (dated_formatted[:leftover].blank? || dated_formatted[:leftover].empty?)

        year = dated_formatted[:year]
        month = dated_formatted[:mon]
        day = dated_formatted[:mday]

        if day && month
          begin
            Date.new(year, month, day)
          rescue ArgumentError
            next
          end
          return { year:, month:, day: }
        elsif month
          begin
            Date.new(year, month, 1)
          rescue ArgumentError
            next
          end
          return { year:, month: }
        elsif year
          return { year: }
        end
      end

      nil
    end
  end
end
