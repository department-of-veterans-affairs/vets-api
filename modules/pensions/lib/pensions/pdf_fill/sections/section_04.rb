# frozen_string_literal: true

require_relative '../section'

module Pensions
  module PdfFill
    # Section IV: Pension Information
    class Section4 < Section
      # Section configuration hash
      KEY = {}.freeze

      ##
      # Expand the form data for pension information.
      #
      # @param form_data [Hash] The form data hash.
      #
      # @return [void]
      #
      # Note: This method modifies `form_data`
      #
      def expand(form_data)
        # Add expansion logic here
      end
    end
  end
end
