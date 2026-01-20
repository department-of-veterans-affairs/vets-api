# frozen_string_literal: true

require 'pdf_fill/extras_generator'
require 'pdf_fill/extras_generator_v2'
require 'pdf_fill/pdf_post_processor'
require 'dependents_benefits/pdf_fill/va21686c'
require 'dependents_benefits/pdf_fill/va21674'
require 'utilities/date_parser'
require 'forwardable'

module DependentsBenefits
  module PdfFill
    # Provides functionality to fill and process PDF forms.
    #
    # This module includes methods to register form classes, fill out PDF forms, and handle extra PDF generation.
    module Filler
      # Exception raised when PDF form processing fails
      class PdfFillerException < StandardError; end
      module_function

      # A PdfForms instance for handling standard PDF forms.
      PDF_FORMS = PdfForms.new(Settings.binaries.pdftk)

      # A PdfForms instance for handling Unicode PDF forms with XFdf data format.
      UNICODE_PDF_FORMS = PdfForms.new(Settings.binaries.pdftk, data_format: 'XFdf', utf8_fields: true)

      # A hash mapping form IDs to their corresponding form classes.
      # This constant is intentionally mutable.
      FORM_CLASSES = {} # rubocop:disable Style/MutableConstant

      ##
      # Registers a form class with a specific form ID.
      #
      # @param form_id [String] The form ID to register.
      # @param form_class [Class] The class associated with the form ID.
      #
      def register_form(form_id, form_class)
        FORM_CLASSES[form_id] = form_class
      end

      # Registers form classes for various form IDs.
      {
        DependentsBenefits::ADD_REMOVE_DEPENDENT => DependentsBenefits::PdfFill::Va21686c,
        DependentsBenefits::SCHOOL_ATTENDANCE_APPROVAL => DependentsBenefits::PdfFill::Va21674
      }.each { |form_id, form_class| register_form(form_id, form_class) }

      ##
      # Combines extra pages into the main PDF if necessary.
      #
      # @param old_file_path [String] The path to the original PDF file.
      # @param extras_generator [ExtrasGenerator] The generator for extra pages.
      #
      # @return [String] The path to the final combined PDF.
      #
      def combine_extras(old_file_path, extras_generator, form_class)
        if extras_generator.text?
          file_path = "#{old_file_path.gsub('.pdf', '')}_final.pdf"
          extras_path = extras_generator.generate

          merge_pdfs(old_file_path, extras_path, file_path)
          # Adds links and destinations to the combined PDF
          if extras_generator.try(:section_coordinates) && !extras_generator.section_coordinates.empty?
            pdf_post_processor = PdfPostProcessor.new(old_file_path, file_path, extras_generator.section_coordinates,
                                                      form_class)
            pdf_post_processor.process!
          end

          File.delete(extras_path)
          File.delete(old_file_path)

          file_path
        else
          old_file_path
        end
      end

      ##
      # Merges multiple PDF files into a single PDF file using HexaPDF.
      #
      # @param file_paths [Array<String>] The paths of the PDF files to merge.
      # @param new_file_path [String] The path for the final merged PDF file.
      #
      # @return [void]
      #
      def merge_pdfs(*file_paths, new_file_path)
        # Use the first file as the target document so that we get its metadata and
        # other properties in the merged document without having to do extra steps.
        target = HexaPDF::Document.open(file_paths.first)

        file_paths.drop(1).each do |file_path|
          pdf = HexaPDF::Document.open(file_path)
          pdf.pages.each do |page|
            target.pages << target.import(page)
          end
        end

        target.write(new_file_path)
      end

      ##
      # Fills a form based on the provided saved claim and options.
      #
      # @param saved_claim [SavedClaim] The saved claim containing form data.
      # @param file_name_extension [String, nil] Optional file name extension.
      # @param fill_options [Hash] Options for filling the form.
      #
      # @raise [PdfFillerException] If the form is not found.
      # @return [String] The path to the filled PDF form.
      #
      def fill_form(saved_claim, file_name_extension = nil, fill_options = {})
        form_id = saved_claim.form_id
        form_class = FORM_CLASSES[form_id]

        raise PdfFillerException, "Form #{form_id} was not found." unless form_class

        process_form(form_id, saved_claim.parsed_form, form_class, file_name_extension || saved_claim.id, fill_options)
      end

      ##
      # Fills an ancillary form based on the provided data and form ID.
      #
      # @param form_data [Hash] The data to fill in the form.
      # @param claim_id [String] The ID of the claim.
      # @param form_id [String] The form ID.
      #
      # @return [String] The path to the filled PDF form.
      #
      def fill_ancillary_form(form_data, claim_id, form_id, fill_options = {})
        process_form(form_id, form_data, FORM_CLASSES[form_id], claim_id, fill_options)
      end

      ##
      # Processes a form by filling it with data and saving it to a file.
      #
      # @param form_id [String] The form ID.
      # @param form_data [Hash] The data to fill in the form.
      # @param form_class [Class] The class associated with the form ID.
      # @param file_name_extension [String] The file name extension for the output PDF.
      # @param fill_options [Hash] Options for filling the form.
      #
      # @return [String] The path to the filled PDF form.
      #

      def process_form(form_id, form_data, form_class, file_name_extension, fill_options = {})
        unless fill_options.key?(:show_jumplinks)
          fill_options[:show_jumplinks] = Flipper.enabled?(:pdf_fill_redesign_overflow_jumplinks)
        end

        folder = 'tmp/pdfs'
        FileUtils.mkdir_p(folder)
        file_path = "#{folder}/#{form_id}_#{file_name_extension}.pdf"
        merged_form_data = form_class.new(form_data).merge_fields(fill_options)
        submit_date = Utilities::DateParser.parse(
          fill_options[:created_at] || merged_form_data['signatureDate'] || Time.now.utc
        )

        hash_converter = make_hash_converter(form_id, form_class, submit_date, fill_options)
        new_hash = hash_converter.transform_data(form_data: merged_form_data, pdftk_keys: form_class::KEY)

        has_template = form_class.const_defined?(:TEMPLATE)
        template_path = has_template ? form_class::TEMPLATE : "lib/pdf_fill/forms/pdfs/#{form_id}.pdf"

        PDF_FORMS.fill_form(
          template_path, file_path, new_hash, flatten: Rails.env.production?
        )

        file_path = stamp_form(file_path, submit_date) if should_stamp_form?(form_id, fill_options, submit_date)
        combine_extras(file_path, hash_converter.extras_generator, form_class)
      end

      ##
      # Creates a hash converter for transforming form data into PDF field format
      #
      # @param _form_id [String] The form ID (unused in base implementation)
      # @param form_class [Class] The form class containing date format configuration
      # @param _submit_date [Time] The submission date (unused in base implementation)
      # @param _fill_options [Hash] Additional fill options (unused in base implementation)
      # @return [PdfFill::HashConverter] Configured hash converter with extras generator
      def make_hash_converter(_form_id, form_class, _submit_date, _fill_options)
        extras_generator = ::PdfFill::ExtrasGenerator.new
        ::PdfFill::HashConverter.new(form_class.date_strftime, extras_generator)
      end

      ##
      # Determines if the form should be stamped with e-signature information
      #
      # @param _form_id [String] The form ID (unused in base implementation)
      # @param fill_options [Hash] Options that may include :omit_esign_stamp flag
      # @param submit_date [Time, nil] The submission timestamp
      # @return [Boolean] true if form should be stamped, false otherwise
      def should_stamp_form?(_form_id, fill_options, submit_date)
        return false if fill_options[:omit_esign_stamp]

        submit_date.present?
      end

      ##
      # Stamps the PDF with electronic signature information and VA.gov branding
      #
      # Adds two text stamps to the PDF:
      # 1. Electronic signature statement at bottom-left with timestamp
      # 2. "VA.gov Submission" text at top-right
      #
      # @param file_path [String] Path to the PDF file to stamp
      # @param submit_date [Time] Submission timestamp to include in signature statement
      # @return [String] Path to the stamped PDF file, or original path if stamping fails
      def stamp_form(file_path, submit_date)
        original_path = file_path
        sig = "Signed electronically and submitted via VA.gov at #{format_timestamp(submit_date)}. " \
              'Signee signed with an identity-verified account.'
        initial_stamp_path = PDFUtilities::DatestampPdf.new(file_path).run(
          text: sig, x: 5, y: 5, text_only: true, size: 9
        )
        file_path = initial_stamp_path
        file_path = PDFUtilities::DatestampPdf.new(initial_stamp_path).run(
          text: 'VA.gov Submission', x: 510, y: 775, text_only: true, size: 9
        )
        file_path
      rescue => e
        Rails.logger.error("Error stamping form for PdfFill: #{file_path}, error: #{e.message}")
        original_path
      ensure
        File.delete(initial_stamp_path) if initial_stamp_path
      end

      # Formats the timestamp for the PDF footer
      def format_timestamp(datetime)
        return nil if datetime.blank?

        "#{datetime.utc.strftime('%H:%M')} UTC #{datetime.utc.strftime('%Y-%m-%d')}"
      end
    end
  end
end
