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
      DEFAULT_FOREIGN_SCHOOLS_LIMIT = 4
      DEFAULT_BRANCH_LOCATION_LIMIT = 4
      TMP_DIR = 'tmp/pdfs'
      FORM_CLASS = PdfFill::Forms::Va220839

      def initialize(form_data, main_form_filler, file_name_suffix = SecureRandom.hex)
        @form_data = form_data
        @main_form_filler = main_form_filler
        @file_name_suffix = file_name_suffix
      end

      def process
        FileUtils.mkdir_p(TMP_DIR)
        merged_form_data = FORM_CLASS.new(@form_data).merge_fields
        hash_converter = HashConverter.new(FORM_CLASS.date_strftime, ExtrasGenerator.new)

        us_schools = merged_form_data['usSchools']
        foreign_schools = merged_form_data['foreignSchools']
        branch_locations = merged_form_data['branchCampuses']

        if us_schools.size <= DEFAULT_US_SCHOOLS_LIMIT &&
           foreign_schools.size <= DEFAULT_FOREIGN_SCHOOLS_LIMIT &&
           branch_locations.size <= DEFAULT_BRANCH_LOCATION_LIMIT
          generate_default_form(merged_form_data, hash_converter)
        else
          generate_extended_form(merged_form_data, hash_converter)
        end
      end

      private

      def generate_default_form(merged_form_data, hash_converter)
        pdf_data_hash = hash_converter.transform_data(form_data: merged_form_data, pdftk_keys: FORM_CLASS::KEY)

        file_path = File.join(TMP_DIR, "22-0839_#{@file_name_suffix}.pdf")
        PDF_FORMS.fill_form(DEFAULT_TEMPLATE_PATH, file_path, pdf_data_hash, flatten: Rails.env.production?)
        file_path
      end

      def generate_extended_form(merged_form_data, hash_converter)
        extra_us_schools = extract_extra_from_array(merged_form_data['usSchools'] || [],
                                                    DEFAULT_US_SCHOOLS_LIMIT)
        extra_foreign_schools = extract_extra_from_array(merged_form_data['foreignSchools'] || [],
                                                         DEFAULT_FOREIGN_SCHOOLS_LIMIT)
        extra_branch_locations = extract_extra_from_array(merged_form_data['branchCampuses'] || [],
                                                          DEFAULT_BRANCH_LOCATION_LIMIT)

        pdf_data_hash = hash_converter.transform_data(form_data: merged_form_data, pdftk_keys: FORM_CLASS::KEY)

        add_extras(hash_converter, extra_us_schools, :us_school_to_text, 0, 'Additional US School')
        add_extras(hash_converter, extra_foreign_schools, :foreign_school_to_text, extra_us_schools.size,
                   'Additional Foreign School')
        add_extras(hash_converter, extra_branch_locations, :branch_location_to_text,
                   extra_us_schools.size + extra_foreign_schools.size, 'Additional Branch Campus')

        file_path = File.join(TMP_DIR, "22-0839_#{@file_name_suffix}.pdf")
        PDF_FORMS.fill_form(DEFAULT_TEMPLATE_PATH, file_path, pdf_data_hash, flatten: Rails.env.production?)
        combine_extras(file_path, hash_converter.extras_generator, FORM_CLASS)
      end

      def add_extras(converter, arr, to_text_method, start_i, label)
        arr.each_with_index do |data, i|
          converter.extras_generator.add_text(send(to_text_method, data), {
                                                question_num: start_i + i + 1,
                                                question_text: label
                                              })
        end
      end

      def extract_extra_from_array(arr, count)
        extra = arr[count..] || []
        arr.pop(extra.size)
        extra
      end

      def us_school_to_text(school_data)
        <<~TEXT
          Maximum Number of Students: #{school_data['maximumNumberofStudents']}
          Degree Level: #{school_data['degreeLevel']}
          College: #{school_data['degreeProgram']}
          Maximum Contrib Amount: #{school_data['maximumContributionAmount']}
        TEXT
      end

      def foreign_school_to_text(school_data)
        <<~TEXT
          Maximum Number of Students: #{school_data['maximumNumberofStudents']}
          Degree Level: #{school_data['degreeLevel']}
          Currency: #{school_data['currencyType']}
          Maximum Contrib Amount: #{school_data['maximumContributionAmount']}
        TEXT
      end

      def branch_location_to_text(branch_data)
        <<~TEXT
          Name/Address: #{branch_data['nameAndAddress']}
          Facility Code: #{branch_data['facilityCode']}
        TEXT
      end
    end
  end
end
