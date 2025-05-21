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

          # Formats a planned facility label by looking up facility name in HealthFacility
          # and displaying value if not found
          def format_planned_facility_label(value)
            selected_facility = HealthFacility.find_by(station_number: value)
            if selected_facility.nil?
              value
            else
              "#{selected_facility.station_number} - #{selected_facility.name}"
            end
          end
        end
      end
    end
  end
end
