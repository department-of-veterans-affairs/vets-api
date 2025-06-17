# frozen_string_literal: true

require 'pdf_fill/forms/formatters/base'
require 'date'

module PdfFill
  module Forms
    module Formatters
      class Va1010ez < Base
        DATE_FORMAT = '%m/%d/%Y'
        class << self
          # Formats a date string into the format MM/DD/YYYY.
          # If the date is in the "YYYY-MM-XX" format, it converts it to "MM/YYYY".
          # Returns date_string and logs error if unable to parse date_string
          def format_date(date_string)
            return if date_string.blank?

            date_string = date_string.strip

            # Handle 1990-08-XX and 1990-XX-XX formats where the day or month is not provided
            # Regex matches vets-json-schema regex for some date fields
            if (match = date_string.match(/^(\d{4}|XXXX)-(0[1-9]|1[0-2]|XX)-(0[1-9]|[1-2][0-9]|3[0-1]|XX)$/))
              year, month, day = match.captures

              return year if month == 'XX'
              return "#{month}/#{year}" if day == 'XX'
            end

            begin
              # Try ISO 8601 first (e.g., "1980-01-31")
              Date.iso8601(date_string).strftime(DATE_FORMAT)
            rescue Date::Error
              # Try MM/DD/YYYY fallback (e.g., "01/31/1980")
              begin
                Date.strptime(date_string, DATE_FORMAT).strftime(DATE_FORMAT)
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
