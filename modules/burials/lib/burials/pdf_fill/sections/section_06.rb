# frozen_string_literal: true

require_relative '../section'

module Burials
  module PdfFill
    # Section VI: Plot / Transportation allowance Information
    class Section6 < Section
      # Section configuration hash
      KEY = {
        # 23
        'hasPlotExpenseResponsibility' => {
          key: 'form1[0].#subform[83].ResponsibleForPlotIntermentCostYes[0]'
        },
        'noPlotExpenseResponsibility' => {
          key: 'form1[0].#subform[83].ResponsibleForPlotIntermentCostNo[0]'
        },
        # 24
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
        # special case: the UI only has a 'yes' checkbox, so the PDF 'noTransportation' checkbox can never be true.
        form_data['hasTransportation'] = select_radio(form_data['transportationExpenses'])
        expand_checkbox_in_place(form_data, 'plotExpenseResponsibility')
      end
    end
  end
end
