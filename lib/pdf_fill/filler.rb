# frozen_string_literal: true

require 'pdf_fill/forms/va21p527ez'
require 'pdf_fill/forms/va21p530'
require 'pdf_fill/forms/va214142'
require 'pdf_fill/forms/va210781a'
require 'pdf_fill/forms/va210781'
require 'pdf_fill/forms/va218940'
require 'pdf_fill/forms/va1010cg'
require 'pdf_fill/forms/va1010ez'
require 'pdf_fill/forms/va686c674'
require 'pdf_fill/forms/va281900'
require 'pdf_fill/forms/va288832'
require 'pdf_fill/forms/va21674'
require 'pdf_fill/forms/va210538'
require 'pdf_fill/forms/va261880'
require 'pdf_fill/forms/va5655'

module PdfFill
  module Filler
    module_function

    PDF_FORMS = PdfForms.new(Settings.binaries.pdftk)
    UNICODE_PDF_FORMS = PdfForms.new(Settings.binaries.pdftk, data_format: 'XFdf', utf8_fields: true)
    FORM_CLASSES = {
      '21P-527EZ' => PdfFill::Forms::Va21p527ez,
      '21P-530' => PdfFill::Forms::Va21p530,
      '21-4142' => PdfFill::Forms::Va214142,
      '21-0781a' => PdfFill::Forms::Va210781a,
      '21-0781' => PdfFill::Forms::Va210781,
      '21-8940' => PdfFill::Forms::Va218940,
      '10-10CG' => PdfFill::Forms::Va1010cg,
      '10-10EZ' => PdfFill::Forms::Va1010ez,
      '686C-674' => PdfFill::Forms::Va686c674,
      '28-1900' => PdfFill::Forms::Va281900,
      '28-8832' => PdfFill::Forms::Va288832,
      '21-674' => PdfFill::Forms::Va21674,
      '21-0538' => PdfFill::Forms::Va210538,
      '26-1880' => PdfFill::Forms::Va261880,
      '5655' => PdfFill::Forms::Va5655
    }.freeze

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

    def fill_form(saved_claim, file_name_extension = nil, fill_options = {})
      form_id = saved_claim.form_id
      form_class = FORM_CLASSES[form_id]

      process_form(form_id, saved_claim.parsed_form, form_class, file_name_extension || saved_claim.id, fill_options)
    end

    def fill_ancillary_form(form_data, claim_id, form_id)
      process_form(form_id, form_data, FORM_CLASSES[form_id], claim_id)
    end

    def process_form(form_id, form_data, form_class, file_name_extension, fill_options = {})
      folder = 'tmp/pdfs'
      FileUtils.mkdir_p(folder)
      file_path = "#{folder}/#{form_id}_#{file_name_extension}.pdf"
      hash_converter = HashConverter.new(form_class.date_strftime)
      new_hash = hash_converter.transform_data(
        form_data: form_class.new(form_data).merge_fields(fill_options),
        pdftk_keys: form_class::KEY
      )
      (form_id == SavedClaim::CaregiversAssistanceClaim::FORM ? UNICODE_PDF_FORMS : PDF_FORMS).fill_form(
        "lib/pdf_fill/forms/pdfs/#{form_id}.pdf",
        file_path,
        new_hash,
        flatten: Rails.env.production?
      )

      combine_extras(file_path, hash_converter.extras_generator)
    end
  end
end
