# frozen_string_literal: true

require 'pdf_fill/forms/va21p0969'
require 'pdf_fill/forms/va21p530'
require 'pdf_fill/forms/va21p530v2'
require 'pdf_fill/forms/va214142'
require 'pdf_fill/forms/va210781a'
require 'pdf_fill/forms/va210781'
require 'pdf_fill/forms/va218940'
require 'pdf_fill/forms/va1010cg'
require 'pdf_fill/forms/va686c674'
require 'pdf_fill/forms/va686c674v2'
require 'pdf_fill/forms/va281900'
require 'pdf_fill/forms/va288832'
require 'pdf_fill/forms/va21674'
require 'pdf_fill/forms/va21674v2'
require 'pdf_fill/forms/va210538'
require 'pdf_fill/forms/va261880'
require 'pdf_fill/forms/va5655'

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
      '21P-0969' => PdfFill::Forms::Va21p0969,
      '21P-530' => PdfFill::Forms::Va21p530,
      '21P-530V2' => PdfFill::Forms::Va21p530v2,
      '21-4142' => PdfFill::Forms::Va214142,
      '21-0781a' => PdfFill::Forms::Va210781a,
      '21-0781' => PdfFill::Forms::Va210781,
      '21-8940' => PdfFill::Forms::Va218940,
      '10-10CG' => PdfFill::Forms::Va1010cg,
      '686C-674' => PdfFill::Forms::Va686c674,
      '686C-674-V2' => PdfFill::Forms::Va686c674v2,
      '28-1900' => PdfFill::Forms::Va281900,
      '28-8832' => PdfFill::Forms::Va288832,
      '21-674' => PdfFill::Forms::Va21674,
      '21-674-V2' => PdfFill::Forms::Va21674v2,
      '21-0538' => PdfFill::Forms::Va210538,
      '26-1880' => PdfFill::Forms::Va261880,
      '5655' => PdfFill::Forms::Va5655
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
    def combine_extras(old_file_path, extras_generator)
      if extras_generator.text?
        file_path = "#{old_file_path.gsub('.pdf', '')}_final.pdf"
        extras_path = extras_generator.generate

        PDF_FORMS.cat(old_file_path, extras_path, file_path)

        File.delete(extras_path)
        File.delete(old_file_path)

        file_path
      else
        old_file_path
      end
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
    def fill_ancillary_form(form_data, claim_id, form_id)
      process_form(form_id, form_data, FORM_CLASSES[form_id], claim_id)
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
      folder = 'tmp/pdfs'
      FileUtils.mkdir_p(folder)
      file_path = "#{folder}/#{form_id}_#{file_name_extension}.pdf"
      hash_converter = HashConverter.new(form_class.date_strftime)
      new_hash = hash_converter.transform_data(
        form_data: form_class.new(form_data).merge_fields(fill_options),
        pdftk_keys: form_class::KEY
      )

      has_template = form_class.const_defined?(:TEMPLATE)
      template_path = has_template ? form_class::TEMPLATE : "lib/pdf_fill/forms/pdfs/#{form_id}.pdf"

      (form_id == SavedClaim::CaregiversAssistanceClaim::FORM ? UNICODE_PDF_FORMS : PDF_FORMS).fill_form(
        template_path,
        file_path,
        new_hash,
        flatten: Rails.env.production?
      )

      combine_extras(file_path, hash_converter.extras_generator)
    end
  end
end
