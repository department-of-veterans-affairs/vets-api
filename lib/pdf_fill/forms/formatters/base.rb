# frozen_string_literal: true

module PdfFill
  module Forms
    module Formatters
      class Base
        class << self
          # Format helpers - Each method takes an input value and returns a formatted version of it.
          # These methods **do not modify** the @form_data object directly, but instead return the formatted output.
          #
          # Because each pdf often has different formatting needs, common formatters can live here, but any custom ones
          # specific to a form can be added in a class that extends this base class

          # Formats a numeric value into a currency string
          def format_currency(value)
            ActiveSupport::NumberHelper.number_to_currency(value)
          end
        end
      end
    end
  end
end
