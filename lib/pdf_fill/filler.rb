# frozen_string_literal: true

require 'pdf_fill/extras_generator'
require 'pdf_fill/extras_generator_v2'
require 'pdf_fill/pdf_post_processor'
require 'pdf_fill/forms/va214142'
require 'pdf_fill/forms/va2141422024'
require 'pdf_fill/forms/va214192'
require 'pdf_fill/forms/va210781a'
require 'pdf_fill/forms/va210781'
require 'pdf_fill/forms/va210781v2'
require 'pdf_fill/forms/va218940'
require 'pdf_fill/forms/va1010cg'
require 'pdf_fill/forms/va1010ez'
require 'pdf_fill/forms/va1010ezr'
require 'pdf_fill/forms/va686c674'
require 'pdf_fill/forms/va686c674v2'
require 'pdf_fill/forms/va281900'
require 'pdf_fill/forms/va288832'
require 'pdf_fill/forms/va210779'
require 'pdf_fill/forms/va21674'
require 'pdf_fill/forms/va21674v2'
require 'pdf_fill/forms/va210538'
require 'pdf_fill/forms/va21p530a'
require 'pdf_fill/forms/va261880'
require 'pdf_fill/forms/va5655'
require 'pdf_fill/forms/va220839'
require 'pdf_fill/forms/va220803'
require 'pdf_fill/forms/va2210216'
require 'pdf_fill/forms/va2210215'
require 'pdf_fill/forms/va2210215a'
require 'pdf_fill/forms/va221919'
require 'pdf_fill/forms/va228794'
require 'pdf_fill/forms/va220976'
require 'pdf_fill/forms/va2210272'
require 'pdf_fill/forms/va2210275'
require 'pdf_fill/forms/va212680'
require 'pdf_fill/processors/va2210215_continuation_sheet_processor'
require 'pdf_fill/processors/va228794_processor'
require 'pdf_fill/processors/va220839_processor'
require 'pdf_fill/processors/va220976_processor'
require 'utilities/date_parser'
require 'forwardable'

# rubocop:disable Metrics/ModuleLength
module PdfFill
  # Provides functionality to fill and process PDF forms.
  #
  # This module includes methods to register form classes, fill out PDF forms, and handle extra PDF generation.
  module Filler
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
      '21-4142' => PdfFill::Forms::Va214142,
      '21-4142-2024' => PdfFill::Forms::Va2141422024,
      '21-4192' => PdfFill::Forms::Va214192,
      '21-0781a' => PdfFill::Forms::Va210781a,
      '21-0781' => PdfFill::Forms::Va210781,
      '21-0781V2' => PdfFill::Forms::Va210781v2,
      '21-8940' => PdfFill::Forms::Va218940,
      '21P-530A' => PdfFill::Forms::Va21p530a,
      '21-2680' => PdfFill::Forms::Va212680,
      '10-10CG' => PdfFill::Forms::Va1010cg,
      '10-10EZ' => PdfFill::Forms::Va1010ez,
      '10-10EZR' => PdfFill::Forms::Va1010ezr,
      '686C-674' => PdfFill::Forms::Va686c674,
      '686C-674-V2' => PdfFill::Forms::Va686c674v2,
      '28-1900' => PdfFill::Forms::Va281900,
      '28-8832' => PdfFill::Forms::Va288832,
      '21-674' => PdfFill::Forms::Va21674,
      '21-674-V2' => PdfFill::Forms::Va21674v2,
      '26-1880' => PdfFill::Forms::Va261880,
      '5655' => PdfFill::Forms::Va5655,
      '22-0839' => PdfFill::Forms::Va220839,
      '22-0803' => PdfFill::Forms::Va220803,
      '22-0976' => PdfFill::Forms::Va220976,
      '21-0779' => PdfFill::Forms::Va210779,
      '22-8794' => PdfFill::Forms::Va228794,
      '22-10216' => PdfFill::Forms::Va2210216,
      '22-10215' => PdfFill::Forms::Va2210215,
      '22-10215a' => PdfFill::Forms::Va2210215a,
      '22-1919' => PdfFill::Forms::Va221919,
      '22-10272' => PdfFill::Forms::Va2210272,
      '22-10275' => PdfFill::Forms::Va2210275
    }.each do |form_id, form_class|
      register_form(form_id, form_class)
    end

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

      # NOTE: In deployed environments we use the `flatten` flag when calling `fill_form`, which removes
      # all of the form metadata. HexaPDF validation fails when the form metadata has been removed,
      # so we should not validate the merged document in deployed environments
      target.write(new_file_path, validate: !Rails.env.production?)
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
    # Fills a form using HexaPDF instead of PDFtk
    #
    # @param template_path [String] The path to the PDF template.
    # @param output_path [String] The path to save the filled PDF.
    # @param hash_data [Hash] The data to fill in the form.
    #
    # @return [None]
    #

    def fill_form_with_hexapdf(template_path, output_path, hash_data)
      Rails.logger.info("PdfFill::Filler HexaPDF template: #{template_path}") if Flipper.enabled?(:acroform_debug_logs)
      doc = HexaPDF::Document.open(template_path)
      form = doc.acro_form
      raise 'No AcroForm found in PDF template.' if form.nil?

      form.fill(hash_data)
      doc.write(output_path)
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
    # rubocop:disable Metrics/MethodLength
    def process_form(form_id, form_data, form_class, file_name_extension, fill_options = {})
      unless fill_options.key?(:show_jumplinks)
        fill_options[:show_jumplinks] = Flipper.enabled?(:pdf_fill_redesign_overflow_jumplinks)
      end

      # more complex logic is handled by a dedicated 'processor' class
      case form_id
      when '22-10215'
        if form_data['programs'] && form_data['programs'].length > 16
          return process_form_with_continuation_sheets(form_id, form_data, form_class, file_name_extension,
                                                       fill_options)
        end
      when '22-0839'
        return PdfFill::Processors::VA220839Processor.new(form_data, self, file_name_extension).process
      when '22-0976'
        return PdfFill::Processors::VA220976Processor.new(form_data, self, file_name_extension).process
      when '22-8794'
        return PdfFill::Processors::VA228794Processor.new(form_data, self, file_name_extension).process
      end

      folder = 'tmp/pdfs'
      FileUtils.mkdir_p(folder)
      file_path = "#{folder}/#{form_id}_#{file_name_extension}.pdf"

      merged_form_data = form_class.new(form_data).merge_fields(fill_options)

      submit_date = Utilities::DateParser.parse(
        fill_options[:created_at] || merged_form_data['signatureDate'] || Time.now.utc
      )

      form_instance = form_class.new(merged_form_data)

      # Dynamic KEY support (same pattern as question_key/template)
      pdftk_keys = form_instance.try(:key) || form_class::KEY
      hash_converter = make_hash_converter(form_id, form_class, submit_date, fill_options, merged_form_data)
      new_hash = hash_converter.transform_data(form_data: merged_form_data, pdftk_keys:)

      has_template = form_class.const_defined?(:TEMPLATE)

      # Try instance method first (for dynamic templates), fallback to constant
      template_path = if form_instance.respond_to?(:template)
                        form_instance.template
                      elsif has_template
                        form_class::TEMPLATE
                      else
                        "lib/pdf_fill/forms/pdfs/#{form_id}.pdf"
                      end

      if fill_options.fetch(:use_hexapdf, false)
        fill_form_with_hexapdf(template_path, file_path, new_hash)
      else
        unicode_pdf_form_list = [SavedClaim::CaregiversAssistanceClaim::FORM,
                                 EVSS::DisabilityCompensationForm::SubmitForm0781::FORM_ID_0781V2]
        (form_id.in?(unicode_pdf_form_list) ? UNICODE_PDF_FORMS : PDF_FORMS).fill_form(
          template_path, file_path, new_hash, flatten: Rails.env.production?
        )
      end

      file_path = stamp_form(file_path, submit_date) if should_stamp_form?(form_id, fill_options, submit_date)
      combine_extras(file_path, hash_converter.extras_generator, form_class)
    end
    # rubocop:enable Metrics/MethodLength

    ##
    # Processes 22-10215 forms with continuation sheets for overflow programs.
    #
    # @param form_id [String] The form ID (should be '22-10215').
    # @param form_data [Hash] The data to fill in the form.
    # @param form_class [Class] The class associated with the form ID.
    # @param file_name_extension [String] The file name extension for the output PDF.
    # @param fill_options [Hash] Options for filling the form.
    #
    # @return [String] The path to the combined PDF form.
    #
    def process_form_with_continuation_sheets(_form_id, form_data, _form_class, file_name_extension, fill_options = {})
      processor = PdfFill::Processors::VA2210215ContinuationSheetProcessor.new(
        form_data,
        file_name_extension,
        fill_options,
        self
      )
      processor.process
    end

    # Pension/Burial Team to remove instance changes after V2 in production
    def make_hash_converter(form_id, form_class, submit_date, fill_options, form_data = {})
      form_instance = form_class.new(form_data) if form_data.present?
      question_key = form_instance.try(:question_key) || form_class::QUESTION_KEY
      sections = form_instance.try(:sections) || form_class::SECTIONS

      extras_generator =
        if fill_options.fetch(:extras_redesign, false)
          ExtrasGeneratorV2.new(
            form_name: form_id.sub(/V2\z/, ''),
            submit_date:,
            question_key:,
            start_page: form_class::START_PAGE,
            sections:,
            label_width: form_class::DEFAULT_LABEL_WIDTH,
            show_jumplinks: fill_options.fetch(:show_jumplinks, false),
            use_hexapdf: fill_options.fetch(:use_hexapdf, false)
          )
        else
          ExtrasGenerator.new(use_hexapdf: fill_options.fetch(:use_hexapdf, false))
        end
      HashConverter.new(form_class.date_strftime, extras_generator)
    end

    def should_stamp_form?(form_id, fill_options, submit_date)
      return false if fill_options[:omit_esign_stamp]

      # special exception for dependents that isn't in extras_redesign
      dependents = %w[686C-674 686C-674-V2 21-674 21-674-V2].include?(form_id)

      # If the form is being generated with the overflow redesign, stamp the top and bottom of the document before the
      # form is combined with the extras overflow pages. This allows the stamps to be placed correctly for the redesign
      # implemented in lib/pdf_fill/extras_generator_v2.rb.
      (fill_options[:extras_redesign] || dependents) && submit_date.present?
    end

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
# rubocop:enable Metrics/ModuleLength
