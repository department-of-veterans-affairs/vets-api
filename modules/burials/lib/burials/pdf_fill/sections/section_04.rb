# frozen_string_literal: true

require_relative '../section'

module IncomeAndAssets
  module PdfFill
    # Section IV: Final Resting Place Information
    class Section4 < Section
      # Section configuration hash
      KEY = {}.freeze

      ##
      # Expands the form data for Section 4.
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
