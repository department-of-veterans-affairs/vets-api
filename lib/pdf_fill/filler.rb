# frozen_string_literal: true

module PdfFill
  module Filler
    module_function

    PDF_FORMS = PdfForms.new(Settings.binaries.pdftk)
    FORM_CLASSES = {
      '21P-527EZ' => PdfFill::Forms::Va21p527ez,
      '21P-530' => PdfFill::Forms::Va21p530,
      '21-4142' => PdfFill::Forms::Va214142,
      '21-0781a' => PdfFill::Forms::Va210781a,
      '21-0781' => PdfFill::Forms::Va210781,
      '21-8940' => PdfFill::Forms::Va218940,
      '10-10CG' => PdfFill::Forms::Va1010cg
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

    def fill_form(saved_claim)
      form_id = saved_claim.form_id
      form_class = FORM_CLASSES[form_id]

      process_form(form_id, saved_claim.parsed_form, form_class, saved_claim.id)
    end

    def fill_ancillary_form(form_data, claim_id, form_id)
      process_form(form_id, form_data, FORM_CLASSES[form_id], claim_id)
    end

    def process_form(form_id, form_data, form_class, claim_id)
      folder = 'tmp/pdfs'
      FileUtils.mkdir_p(folder)
      file_path = "#{folder}/#{form_id}_#{claim_id}.pdf"
      hash_converter = HashConverter.new(form_class.date_strftime)
      new_hash = hash_converter.transform_data(
        form_data: form_class.new(form_data).merge_fields,
        pdftk_keys: form_class::KEY
      )
      PDF_FORMS.fill_form(
        "lib/pdf_fill/forms/pdfs/#{form_id}.pdf",
        file_path,
        new_hash,
        flatten: Rails.env.production?
      )

      combine_extras(file_path, hash_converter.extras_generator)
    end
  end
end
