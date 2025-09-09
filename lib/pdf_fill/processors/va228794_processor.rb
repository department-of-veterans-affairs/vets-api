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
        setup_directory
        certifying_officials = @form_data['additionalCertifyingOfficials'] || []
        if certifying_officials.size <= DEFAULT_FORM_OFFICIALS_LIMIT
          generate_default_form
        else
          generate_extended_form
        end
      end

      private

      def setup_directory
        FileUtils.mkdir_p(TMP_DIR)
      end

      def generate_default_form
        merged_form_data = FORM_CLASS.new(@form_data).merge_fields

        extras_generator = ExtrasGenerator.new
        hash_converter = HashConverter.new(FORM_CLASS.date_strftime, extras_generator)

        pdf_data_hash = hash_converter.transform_data(form_data: merged_form_data, pdftk_keys: FORM_CLASS::KEY)

        file_path = File.join(TMP_DIR, "22-8794.pdf")
        PDF_FORMS.fill_form(DEFAULT_TEMPLATE_PATH, file_path, pdf_data_hash, flatten: Rails.env.production?)
        file_path
      end

      def generate_extended_form
        merged_form_data = FORM_CLASS.new(@form_data).merge_fields
        r = /additionalCertifyingOfficials_(?<i>\d+)/
        extra_officials = merged_form_data.select do |k, _v|
          (m = r.match(k)) && (m[:i].to_i >= DEFAULT_FORM_OFFICIALS_LIMIT)
        end.values

        extras_generator = ExtrasGenerator.new
        hash_converter = HashConverter.new(FORM_CLASS.date_strftime, extras_generator)

        pdf_data_hash = hash_converter.transform_data(form_data: merged_form_data, pdftk_keys: FORM_CLASS::KEY)

        extra_officials.each_with_index do |official_data, i|
          hash_converter.extras_generator.add_text(certifying_official_to_text(official_data), {
            question_num: DEFAULT_FORM_OFFICIALS_LIMIT + i + 1,
            question_text: "Additional Certifying Official"
          })
        end

        file_path = File.join(TMP_DIR, "22-8794.pdf")
        PDF_FORMS.fill_form(DEFAULT_TEMPLATE_PATH, file_path, pdf_data_hash, flatten: Rails.env.production?)
        combine_extras(file_path, hash_converter.extras_generator, FORM_CLASS)
      end

      def certifying_official_to_text(official_data)
        str = <<~TEXT
          #{official_data['fullName']}, #{official_data['title']}
          #{official_data['emailAddress']}
          #{official_data['phoneNumber']}
          Training Date: #{official_data['trainingCompletionDate']}
          Receives Benefits: #{official_data['recievesBenegits'] ? 'Yes' : 'No'}
        TEXT
      end

      # def generate_continuation_intro_page
      #   intro_file_path = "#{@folder}/#{CONTINUATION_SHEET_FORM_ID}-Intro_#{@file_name_extension}.pdf"
      #   FileUtils.cp(CONTINUATION_SHEET_INTRO_PDF_PATH, intro_file_path)
      #   @pdf_files << intro_file_path
      # end

      # def generate_continuation_sheets
      #   remaining_programs.each_slice(PROGRAMS_PER_PAGE).with_index(1) do |program_batch, page_number|
      #     continuation_path = "#{@folder}/#{CONTINUATION_SHEET_FORM_ID}_#{@file_name_extension}_page#{page_number}.pdf"
      #     fill_pdf_form(
      #       form_id: CONTINUATION_SHEET_FORM_ID,
      #       form_data: @form_data.merge('programs' => program_batch),
      #       output_path: continuation_path,
      #       template_path: CONTINUATION_SHEET_PDF_PATH,
      #       page_number:,
      #       total_pages: total_pages_count
      #     )
      #     @pdf_files << continuation_path
      #   end
      # end

      # def fill_pdf_form(form_id:, form_data:, output_path:, template_path:, **options)
      #   form_class = PdfFill::Filler::FORM_CLASSES[form_id]
      #   merged_form_data = form_class.new(form_data).merge_fields(@fill_options.merge(options))
      #   submit_date = Utilities::DateParser.parse(
      #     merged_form_data['signatureDate'] || @fill_options[:created_at] || Time.now.utc
      #   )

      #   hash_converter = make_hash_converter(form_id, form_class, submit_date, @fill_options)
      #   new_hash = hash_converter.transform_data(form_data: merged_form_data, pdftk_keys: form_class::KEY)

      #   PDF_FORMS.fill_form(template_path, output_path, new_hash, flatten: Rails.env.production?)
      # end

      # def combine_pdf_pages
      #   final_file_path = "#{@folder}/22-10215_#{@file_name_extension}.pdf"
      #   PDF_FORMS.cat(*@pdf_files, final_file_path)

      #   log_completion(final_file_path)
      #   final_file_path
      # end

      # def cleanup_temporary_files
      #   @pdf_files.each do |file|
      #     FileUtils.rm_f(file)
      #   end
      # end

      # def remaining_programs
      #   @remaining_programs ||= @programs.from(PROGRAMS_PER_PAGE) || []
      # end

      # def total_pages_count
      #   (remaining_programs.length / PROGRAMS_PER_PAGE.to_f).ceil
      # end

      # def log_completion(_final_file_path)
      #   Rails.logger.info(
      #     'PdfFill done with continuation sheets',
      #     @fill_options.merge(
      #       form_id: '22-10215',
      #       file_name_extension: @file_name_extension,
      #       total_pages: total_pages_count,
      #       total_programs: @programs.length
      #     )
      #   )
      # end
    end
  end
end
