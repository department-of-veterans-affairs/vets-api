# frozen_string_literal: true

require 'increase_compensation/pdf_fill/section'

module IncreaseCompensation
  module PdfFill
    # Section V:  REMARKS
    class Section5 < Section
      # Section configuration hash
      KEY = {
        'remarks' => {
          key: 'form1[0].#subform[4].Remarks_Ifany[0]'
        }
      }.freeze
      def expand(form_data = {})
      end
    end
  end
end
