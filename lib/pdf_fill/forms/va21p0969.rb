# frozen_string_literal: true

require 'pdf_fill/forms/form_base'

module PdfFill
  module Forms
    class Va21p0969 < FormBase
      KEY = {}.freeze

      def merge_fields(_options = {})
        @form_data
      end
    end
  end
end
