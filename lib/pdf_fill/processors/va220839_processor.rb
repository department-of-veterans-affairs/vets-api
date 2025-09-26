# frozen_string_literal: true

require 'fileutils'

module PdfFill
  module Processors
    class VA220839Processor
      extend Forwardable

      def_delegators :@main_form_filler, :combine_extras

      PDF_FORMS = PdfForms.new(Settings.binaries.pdftk)
      DEFAULT_TEMPLATE_PATH = 'lib/pdf_fill/forms/pdfs/22-0839.pdf'
      DEFAULT_US_SCHOOLS_LIMIT = 11
      TMP_DIR = 'tmp/pdfs'
      FORM_CLASS = PdfFill::Forms::Va220839

      def initialize(form_data, main_form_filler)
        @form_data = form_data
        @main_form_filler = main_form_filler
      end

      def process
        FileUtils.mkdir_p(TMP_DIR)
        merged_form_data = FORM_CLASS.new(@form_data).merge_fields
        hash_converter = HashConverter.new(FORM_CLASS.date_strftime, ExtrasGenerator.new)

        us_schools = (@form_data['yellowRibbonProgramAgreementRequest'] || []).filter { |s| s['currencyType'] == 'USD' }

        if us_schools.size <= DEFAULT_US_SCHOOLS_LIMIT
          generate_default_form(merged_form_data, hash_converter)
        else
          generate_extended_form(merged_form_data, hash_converter)
        end
      end

      private

      def generate_default_form(merged_form_data, hash_converter)
        pdf_data_hash = hash_converter.transform_data(form_data: merged_form_data, pdftk_keys: FORM_CLASS::KEY)

        file_path = File.join(TMP_DIR, '22-0839.pdf')
        PDF_FORMS.fill_form(DEFAULT_TEMPLATE_PATH, file_path, pdf_data_hash, flatten: Rails.env.production?)
        file_path
      end

      def generate_extended_form(merged_form_data, hash_converter)
        extra_us_schools = merged_form_data['usSchools'][DEFAULT_US_SCHOOLS_LIMIT..]
        merged_form_data['usSchools'] = merged_form_data['usSchools'][0...DEFAULT_US_SCHOOLS_LIMIT]

        pdf_data_hash = hash_converter.transform_data(form_data: merged_form_data, pdftk_keys: FORM_CLASS::KEY)

        extra_us_schools.each_with_index do |official_data, i|
          hash_converter.extras_generator.add_text(us_school_to_text(official_data), {
                                                     question_num: DEFAULT_US_SCHOOLS_LIMIT + i + 1,
                                                     question_text: 'Additional US School'
                                                   })
        end

        file_path = File.join(TMP_DIR, '22-0839.pdf')
        PDF_FORMS.fill_form(DEFAULT_TEMPLATE_PATH, file_path, pdf_data_hash, flatten: Rails.env.production?)
        combine_extras(file_path, hash_converter.extras_generator, FORM_CLASS)
      end

      def us_school_to_text(school_data)
        <<~TEXT
          Maximum Number of Students: #{school_data['maximumNumberofStudents']}
          Degree Level: #{school_data['degreeLevel']}
          College: #{school_data['degreeProgram']}
          Maximum Contrib Amount: #{school_data['maximumContributionAmount']}
        TEXT
      end
    end
  end
end
