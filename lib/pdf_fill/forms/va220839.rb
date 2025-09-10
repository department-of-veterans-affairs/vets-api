# frozen_string_literal: true

module PdfFill
  module Forms
    class Va220839 < FormBase
      include FormHelper

      KEY = {
        'agreementType' => {
          key: 'agreement_type',
        },
      }.freeze

      def merge_fields(_options = {})
        form_data
      end
    end
  end
end
