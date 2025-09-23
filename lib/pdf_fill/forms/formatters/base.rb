# frozen_string_literal: true

module PdfFill
  module Forms
    module Formatters
      class Base
        class << self
          # Format helpers - Each method takes an input value and returns a formatted version of it.
          # Because each pdf often has different formatting needs, common formatters can live here, but any custom ones
          # specific to a form can be added in a class that extends this base class

          # Formats a numeric value into a currency string
          def format_currency(value)
            ActiveSupport::NumberHelper.number_to_currency(value)
          end

          # Formats a VA facility label by looking up facility name in HealthFacility
          # Returns facility id if facility is not found
          def format_facility_label(value)
            facility = HealthFacility.find_by(station_number: value)
            if facility.nil?
              value
            else
              "#{facility.station_number} - #{facility.name}"
            end
          end

          # Formats a SSN to be in the format of 123-45-6789
          def format_ssn(value)
            return if value.blank?

            digits = value.to_s.gsub(/\D/, '')

            "#{digits[0..2]}-#{digits[3..4]}-#{digits[5..8]}"
          end

          # Formats a phone number to be in the format of (123) 456-7890
          def format_phone_number(value)
            return if value.blank?

            digits = value.to_s.gsub(/\D/, '')

            "(#{digits[0..2]}) #{digits[3..5]}-#{digits[6..9]}"
          end
        end
      end
    end
  end
end
