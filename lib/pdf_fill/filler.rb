# frozen_string_literal: true
require 'pdf_fill/forms/va21p527ez'
require 'pdf_fill/hash_converter'

module PdfFill
  module Filler
    module_function

    PDF_FORMS = PdfForms.new('pdftk')
    FORM_CLASSES = {
      '21P-527EZ' => PdfFill::Forms::VA21P527EZ
    }.freeze

    def combine_extras(old_file_path, extras_generator)
      if extras_generator.text?
        file_path = "tmp/pdfs/form_#{Time.zone.now}_final.pdf"
        extras_path = extras_generator.generate

        PDF_FORMS.cat(old_file_path, extras_path, file_path)

        File.delete(extras_path)
        File.delete(old_file_path)

        file_path
      else
        old_file_path
      end
    end

    def fill_form(code, form_data)
      form_class = FORM_CLASSES[code]
      folder = 'tmp/pdfs'
      FileUtils.mkdir_p(folder)
      # TODO: add the id of the form to filename and remove timestamp
      file_path = "#{folder}/#{code}_#{Time.zone.now}.pdf"
      hash_converter = HashConverter.new(form_class::DATE_STRFTIME)
      new_hash = hash_converter.transform_data(
        form_data: form_class.new(form_data).merge_fields,
        pdftk_keys: form_class::KEY
      )

      PDF_FORMS.fill_form(
        "lib/pdf_fill/forms/pdfs/#{code}.pdf",
        file_path,
        new_hash
      )

      combine_extras(file_path, hash_converter.extras_generator)
    end
  end
end
