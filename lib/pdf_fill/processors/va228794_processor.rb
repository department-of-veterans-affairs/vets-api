# frozen_string_literal: true

require 'fileutils'

module PdfFill
  module Processors
    class VA228794Processor
      extend Forwardable

      def_delegators :@main_form_filler, :combine_extras

      PDF_FORMS = PdfForms.new(Settings.binaries.pdftk)
      DEFAULT_TEMPLATE_PATH = 'lib/pdf_fill/forms/pdfs/22-8794.pdf'
      DEFAULT_FORM_OFFICIALS_LIMIT = 7
      TMP_DIR = 'tmp/pdfs'
      FORM_CLASS = PdfFill::Forms::Va228794

      def initialize(form_data, main_form_filler)
        @form_data = form_data
        @main_form_filler = main_form_filler
      end

      def process
        FileUtils.mkdir_p(TMP_DIR)
        merged_form_data = FORM_CLASS.new(@form_data).merge_fields
        hash_converter = HashConverter.new(FORM_CLASS.date_strftime, ExtrasGenerator.new)

        certifying_officials = @form_data['additionalCertifyingOfficials'] || []
        if certifying_officials.size <= DEFAULT_FORM_OFFICIALS_LIMIT
          generate_default_form(merged_form_data, hash_converter)
        else
          generate_extended_form(merged_form_data, hash_converter)
        end
      end

      private

      def generate_default_form(merged_form_data, hash_converter)
        pdf_data_hash = hash_converter.transform_data(form_data: merged_form_data, pdftk_keys: FORM_CLASS::KEY)

        file_path = File.join(TMP_DIR, '22-8794.pdf')
        PDF_FORMS.fill_form(DEFAULT_TEMPLATE_PATH, file_path, pdf_data_hash, flatten: Rails.env.production?)
        file_path
      end

      def generate_extended_form(merged_form_data, hash_converter)
        extra_officials = merged_form_data['additionalCertifyingOfficials'][DEFAULT_FORM_OFFICIALS_LIMIT..]
        merged_form_data['additionalCertifyingOfficials'] =
          merged_form_data['additionalCertifyingOfficials'][0..DEFAULT_FORM_OFFICIALS_LIMIT]

        pdf_data_hash = hash_converter.transform_data(form_data: merged_form_data, pdftk_keys: FORM_CLASS::KEY)

        extra_officials.each_with_index do |official_data, i|
          hash_converter.extras_generator.add_text(certifying_official_to_text(official_data), {
                                                     question_num: DEFAULT_FORM_OFFICIALS_LIMIT + i + 1,
                                                     question_text: 'Additional Certifying Official'
                                                   })
        end

        file_path = File.join(TMP_DIR, '22-8794.pdf')
        PDF_FORMS.fill_form(DEFAULT_TEMPLATE_PATH, file_path, pdf_data_hash, flatten: Rails.env.production?)
        combine_extras(file_path, hash_converter.extras_generator, FORM_CLASS)
      end

      def certifying_official_to_text(official_data)
        <<~TEXT
          #{official_data['fullName']}, #{official_data['title']}
          #{official_data['emailAddress']}
          #{official_data['phoneNumber']}
          Training Date: #{official_data['trainingCompletionDate']}
          Receives Benefits: #{official_data['recievesBenegits'] ? 'Yes' : 'No'}
        TEXT
      end
    end
  end
end
