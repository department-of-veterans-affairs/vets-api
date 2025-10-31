# frozen_string_literal: true

require 'increase_compensation/pdf_fill/section'

module IncreaseCompensation
  module PdfFill
    # Section III: EMPLOYMENT STATEMENT
    class Section3 < Section
      include Helpers
      # Hash iterator
      ITERATOR = ::PdfFill::HashConverter::ITERATOR
      # Section configuration hash
      KEY = {}.freeze
      def expand(form_data = {}) end
    end
  end
end
