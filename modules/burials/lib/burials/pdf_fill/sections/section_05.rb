# frozen_string_literal: true

require_relative '../section'

module Burials
  module PdfFill
    # Section V: Burial Allowance Information
    class Section5 < Section
      # Section configuration hash
      KEY = {}.freeze

      ##
      # Expands the form data for Section 5.
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
