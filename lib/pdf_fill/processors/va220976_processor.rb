# frozen_string_literal: true

require 'fileutils'

module PdfFill
  module Processors
    class VA220976Processor
      extend Forwardable

      def_delegators :@main_form_filler, :combine_extras

      PDF_FORMS = PdfForms.new(Settings.binaries.pdftk)
      DEFAULT_TEMPLATE_PATH = 'lib/pdf_fill/forms/pdfs/22-0976.pdf'
      TMP_DIR = 'tmp/pdfs'
      FORM_CLASS = PdfFill::Forms::Va220976

      def initialize(form_data, main_form_filler)
        @form_data = form_data
        @main_form_filler = main_form_filler
      end

      def process
        FileUtils.mkdir_p(TMP_DIR)
        merged_form_data = FORM_CLASS.new(@form_data).merge_fields
        hash_converter = HashConverter.new(FORM_CLASS.date_strftime, ExtrasGenerator.new)

        generate_default_form(merged_form_data, hash_converter)
      end

      private

      def generate_default_form(merged_form_data, hash_converter)
        pdf_data_hash = hash_converter.transform_data(form_data: merged_form_data, pdftk_keys: FORM_CLASS::KEY)

        file_path = File.join(TMP_DIR, '22-0976.pdf')
        PDF_FORMS.fill_form(DEFAULT_TEMPLATE_PATH, file_path, pdf_data_hash, flatten: Rails.env.production?)
        file_path
      end
    end
  end
end
