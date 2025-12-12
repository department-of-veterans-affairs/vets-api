# frozen_string_literal: true

require 'fileutils'
require_relative '../forms/va2210215a'

module PdfFill
  module Processors
    class VA2210215ContinuationSheetProcessor
      extend Forwardable

      def_delegators :@main_form_filler, :make_hash_converter

      PDF_FORMS = PdfForms.new(Settings.binaries.pdftk)
      CONTINUATION_SHEET_FORM_ID = '22-10215a'
      CONTINUATION_SHEET_INTRO_PDF_PATH = 'lib/pdf_fill/forms/pdfs/22-10215a-Intro.pdf'
      CONTINUATION_SHEET_PDF_PATH = 'lib/pdf_fill/forms/pdfs/22-10215a.pdf'
      MAIN_FORM_PDF_PATH = 'lib/pdf_fill/forms/pdfs/22-10215.pdf'
      PROGRAMS_PER_PAGE = 16

      def initialize(form_data, file_name_extension, fill_options, main_form_filler)
        @form_data = form_data
        @file_name_extension = file_name_extension
        @fill_options = fill_options
        @main_form_filler = main_form_filler
        @folder = 'tmp/pdfs'
        @pdf_files = []
        unsorted_programs = @form_data['programs'] || []
        @programs = PdfFill::Forms::Formatters::Va2210215.sort_programs_by_name(unsorted_programs)
        # Update form_data with sorted programs to ensure consistency
        @form_data['programs'] = @programs
      end

      def process
        setup_directory
        generate_all_pdf_pages
        combine_pdf_pages
      ensure
        cleanup_temporary_files
      end

      private

      def setup_directory
        FileUtils.mkdir_p(@folder)
      end

      def generate_all_pdf_pages
        generate_main_form
        return if remaining_programs.empty?

        generate_continuation_intro_page
        generate_continuation_sheets
      end

      def generate_main_form
        main_form_path = "#{@folder}/22-10215_#{@file_name_extension}_main.pdf"

        main_form_data = @form_data.merge('programs' => @programs.first(PROGRAMS_PER_PAGE))
        main_form_data['checkbox'] = 'X'

        fill_pdf_form(
          form_id: '22-10215',
          form_data: main_form_data,
          output_path: main_form_path,
          template_path: MAIN_FORM_PDF_PATH,
          is_main_form: true
        )
        @pdf_files << main_form_path
      end

      def generate_continuation_intro_page
        intro_file_path = "#{@folder}/#{CONTINUATION_SHEET_FORM_ID}-Intro_#{@file_name_extension}.pdf"
        FileUtils.cp(CONTINUATION_SHEET_INTRO_PDF_PATH, intro_file_path)
        @pdf_files << intro_file_path
      end

      def generate_continuation_sheets
        remaining_programs.each_slice(PROGRAMS_PER_PAGE).with_index(1) do |program_batch, page_number|
          continuation_path = "#{@folder}/#{CONTINUATION_SHEET_FORM_ID}_#{@file_name_extension}_page#{page_number}.pdf"
          fill_pdf_form(
            form_id: CONTINUATION_SHEET_FORM_ID,
            form_data: @form_data.merge('programs' => program_batch),
            output_path: continuation_path,
            template_path: CONTINUATION_SHEET_PDF_PATH,
            page_number:,
            total_pages: total_pages_count
          )
          @pdf_files << continuation_path
        end
      end

      def fill_pdf_form(form_id:, form_data:, output_path:, template_path:, **options)
        form_class = PdfFill::Filler::FORM_CLASSES[form_id]
        merged_form_data = form_class.new(form_data).merge_fields(@fill_options.merge(options))
        submit_date = Utilities::DateParser.parse(
          merged_form_data['signatureDate'] || @fill_options[:created_at] || Time.now.utc
        )

        hash_converter = make_hash_converter(form_id, form_class, submit_date, @fill_options)
        new_hash = hash_converter.transform_data(form_data: merged_form_data, pdftk_keys: form_class::KEY)

        PDF_FORMS.fill_form(template_path, output_path, new_hash, flatten: Rails.env.production?)
      end

      def combine_pdf_pages
        final_file_path = "#{@folder}/22-10215_#{@file_name_extension}.pdf"
        PDF_FORMS.cat(*@pdf_files, final_file_path)

        log_completion(final_file_path)
        final_file_path
      end

      def cleanup_temporary_files
        @pdf_files.each do |file|
          FileUtils.rm_f(file)
        end
      end

      def remaining_programs
        @remaining_programs ||= @programs.from(PROGRAMS_PER_PAGE) || []
      end

      def total_pages_count
        (remaining_programs.length / PROGRAMS_PER_PAGE.to_f).ceil
      end

      def log_completion(_final_file_path)
        Rails.logger.info(
          'PdfFill done with continuation sheets',
          @fill_options.merge(
            form_id: '22-10215',
            file_name_extension: @file_name_extension,
            total_pages: total_pages_count,
            total_programs: @programs.length
          )
        )
      end
    end
  end
end
