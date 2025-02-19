# frozen_string_literal: true

require 'pdf_fill/forms/form_base'

module PdfFill
  module Forms
    class Va1010ez < FormBase
      FORM_ID = HealthCareApplication::FORM_ID

      KEY = {
        'veteranFullName' => {
          key: 'F[0].P4[0].LastFirstMiddle[0]'
        }
      }.freeze

      def merge_fields(_options = {})
        merge_full_name
        @form_data
      end

      private

      def merge_full_name
        @form_data['veteranFullName'] =
          combine_full_name(@form_data['veteranFullName'])
      end
    end
  end
end
