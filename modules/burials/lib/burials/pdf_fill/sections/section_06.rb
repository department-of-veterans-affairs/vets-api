# frozen_string_literal: true

require_relative '../section'

module IncomeAndAssets
  module PdfFill
    # Section VI: Plot / Transportation allowance Information
    class Section6 < Section
      # Section configuration hash
      KEY = {}.freeze

      ##
      # Expands the form data for Section 6.
      #
      # @param form_data [Hash]
      #
      # @note Modifies `form_data`
      #
      def expand(form_data)
        # Add expansion logic here
      end
    end
  end
end
