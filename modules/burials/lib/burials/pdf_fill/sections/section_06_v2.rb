# frozen_string_literal: true

require_relative '../section'

module Burials
  module PdfFill
    # Section VI (V2): Transportation allowance information
    class Section6V2 < Section
      # Section configuration hash
      KEY = {
        # Transportation responsibility
        'hasTransportation' => {
          key: 'form1[0].#subform[83].ResponsibleForTransportation[0]'
        }
      }.freeze

      ##
      # Expands the form data for Section 6.
      #
      # @param form_data [Hash]
      #
      # @note Modifies `form_data`
      #
      def expand(form_data)
        form_data['hasTransportation'] = select_radio(form_data['transportationExpenses'])
      end
    end
  end
end
