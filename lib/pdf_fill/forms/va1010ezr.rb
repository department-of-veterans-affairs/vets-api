# frozen_string_literal: true

require 'pdf_fill/forms/form_base'
require 'pdf_fill/forms/field_mappings/va1010ezr'
require 'pdf_fill/forms/formatters/va1010ez'
require 'form1010_ezr/service'

module PdfFill
  module Forms
    class Va1010ezr < FormBase
      FORM_ID = Form1010Ezr::Service::FORM_ID
      FORMATTER = PdfFill::Forms::Formatters::Va1010ez
      KEY = PdfFill::Forms::FieldMappings::Va1010ezr::KEY

      def merge_fields(_options = {})
        merge_full_name('veteranFullName')

        @form_data
      end

      private

      def merge_full_name(type)
        @form_data[type] = FORMATTER.format_full_name(@form_data[type])
      end
    end
  end
end
