# frozen_string_literal: true

require 'pdf_fill/forms/formatters/base'
require 'date'

module PdfFill
  module Forms
    module Formatters
      class Va1010ez < Base
        class << self
          # Formats a date string into the format MM/DD/YYYY.
          # If the date is in the "YYYY-MM-XX" format, it converts it to "MM/YYYY".
          # Returns date_string and logs error if unable to parse date_string
          def format_date(date_string)
            return if date_string.blank?

            # Handle 1990-08-XX format where the day is not provided
            if date_string.match?(/^\d{4}-\d{2}-XX$/)
              year, month = date_string.split('-')
              return "#{month}/#{year}"
            end

            begin
              # Try ISO 8601 first (e.g., "1980-01-31")
              Date.iso8601(date_string).strftime('%m/%d/%Y')
            rescue Date::Error
              # Try MM/DD/YYYY fallback (e.g., "01/31/1980")
              begin
                Date.strptime(date_string, '%m/%d/%Y').strftime('%m/%d/%Y')
              rescue Date::Error
                Rails.logger.error("[#{self}] Unparseable date string", date_string:)
                date_string
              end
            end
          end

          # Formats a full name using components like last, first, middle, and suffix.
          # It returns the name in the format "Last, First, Middle Suffix".
          def format_full_name(full_name)
            return if full_name.blank?

            last = full_name['last']
            first = full_name['first']
            middle = full_name['middle']
            suffix = full_name['suffix']

            name = [last, first].compact.join(', ')
            name += ", #{middle}" if middle&.strip.present?
            name += " #{suffix}" if suffix&.strip.present?
            name
          end
        end
      end
    end
  end
end
