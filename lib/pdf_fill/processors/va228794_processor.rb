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
      DEFAULT_FORM_READ_ONLY_SCO_LIMIT = 4
      REMARKS_LINES = 5
      TMP_DIR = 'tmp/pdfs'
      FORM_CLASS = PdfFill::Forms::Va228794

      def initialize(form_data, main_form_filler, file_name_suffix = SecureRandom.hex)
        @form_data = form_data
        @main_form_filler = main_form_filler
        @file_name_suffix = file_name_suffix
      end

      def process
        FileUtils.mkdir_p(TMP_DIR)
        merged_form_data = FORM_CLASS.new(@form_data).merge_fields
        hash_converter = HashConverter.new(FORM_CLASS.date_strftime, ExtrasGenerator.new)

        certifying_officials = @form_data['additionalCertifyingOfficials'] || []
        read_only_officials = @form_data['readOnlyCertifyingOfficial'] || []
        remarks = @form_data['remarks'] || ''
        if certifying_officials.size <= DEFAULT_FORM_OFFICIALS_LIMIT &&
           read_only_officials.size <= DEFAULT_FORM_READ_ONLY_SCO_LIMIT &&
           remarks.lines.count <= REMARKS_LINES
          generate_default_form(merged_form_data, hash_converter)
        else
          generate_extended_form(merged_form_data, hash_converter)
        end
      end

      private

      def generate_default_form(merged_form_data, hash_converter)
        pdf_data_hash = hash_converter.transform_data(form_data: merged_form_data, pdftk_keys: FORM_CLASS::KEY)

        file_path = File.join(TMP_DIR, "22-8794_#{@file_name_suffix}.pdf")
        PDF_FORMS.fill_form(DEFAULT_TEMPLATE_PATH, file_path, pdf_data_hash, flatten: Rails.env.production?)
        file_path
      end

      def generate_extended_form(merged_form_data, hash_converter)
        # extract extra records that don't fit on pdf for later processing
        extra_certifying_officials = process_additional_certifying_officials(merged_form_data, hash_converter)
        extra_read_only_officials = process_additional_read_only_officials(merged_form_data, hash_converter,
                                                                           extra_certifying_officials.size)
        process_remarks(merged_form_data, hash_converter,
                        extra_certifying_officials.size + extra_read_only_officials.size)

        # convert data that will fit naturally onto the pdf
        pdf_data_hash = hash_converter.transform_data(form_data: merged_form_data, pdftk_keys: FORM_CLASS::KEY)

        # fill in pdf and append extra pages
        file_path = File.join(TMP_DIR, "22-8794_#{@file_name_suffix}.pdf")
        PDF_FORMS.fill_form(DEFAULT_TEMPLATE_PATH, file_path, pdf_data_hash, flatten: Rails.env.production?)
        combine_extras(file_path, hash_converter.extras_generator, FORM_CLASS)
      end

      def extract_extra_from_array(arr, count)
        extra = arr[count..] || []
        arr.pop(extra.size)
        extra
      end

      def certifying_official_to_text(official_data)
        <<~TEXT
          NAME: #{official_data['fullName']}
          TITLE: #{official_data['title']}
          EMAIL: #{official_data['emailAddress']}
          PHONE: #{official_data['phoneNumber']}
          TRAINING DATE: #{official_data['trainingCompletionDate']}
          RECEIVES BENEFITS: #{official_data['receivesBenefits']}
        TEXT
      end

      def read_only_official_to_text(official_data)
        full_name = %w[first middle last].map do |k|
          official_data.dig('fullName', k)
        end.join(' ')
        "NAME: #{full_name}"
      end

      def process_additional_certifying_officials(merged_form_data, hash_converter)
        extra_certifying_officials = extract_extra_from_array(merged_form_data['additionalCertifyingOfficials'] || [],
                                                              DEFAULT_FORM_OFFICIALS_LIMIT)
        extra_certifying_officials.each_with_index do |official_data, i|
          hash_converter.extras_generator.add_text(certifying_official_to_text(official_data), {
                                                     question_num: i + 1,
                                                     question_text: 'ADDITIONAL CERTIFYING OFFICIAL'
                                                   })
        end

        extra_certifying_officials
      end

      def process_additional_read_only_officials(merged_form_data, hash_converter, start_i)
        extra_read_only_officials = extract_extra_from_array(merged_form_data['readOnlyCertifyingOfficial'] || [],
                                                             DEFAULT_FORM_READ_ONLY_SCO_LIMIT)
        extra_read_only_officials.each_with_index do |rof_data, i|
          hash_converter.extras_generator.add_text(read_only_official_to_text(rof_data), {
                                                     question_num: start_i + i + 1,
                                                     question_text: 'READ ONLY OFFICIAL'
                                                   })
        end
        extra_read_only_officials
      end

      def process_remarks(merged_form_data, hash_converter, start_i)
        remarks = merged_form_data['remarks'] || ''
        if remarks.lines.count > REMARKS_LINES
          merged_form_data['remarks'] = 'See attached page'
          question_num = start_i + 1
          hash_converter.extras_generator.add_text(remarks, {
                                                     question_num:,
                                                     question_text: 'REMARKS'
                                                   })
        end
      end
    end
  end
end
