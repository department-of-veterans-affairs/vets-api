# frozen_string_literal: true

require 'pdf_fill/forms/formatters/base'

module PdfFill
  module Forms
    module Formatters
      class Va1010ezr < Base
        class << self
          def format_phone_number(value)
            return if value.blank?

            digits = value.to_s.gsub(/\D/, '')

            "(#{digits[0..2]}) #{digits[3..5]}-#{digits[6..9]}"
          end

          def format_ssn(value)
            return if value.blank?

            digits = value.to_s.gsub(/\D/, '')

            "#{digits[0..2]}-#{digits[3..4]}-#{digits[5..8]}"
          end
        end
      end
    end
  end
end
