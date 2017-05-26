# frozen_string_literal: true
require 'pdf_fill/forms/va21p527ez'
require 'pdf_fill/hash_converter'

module PdfFill
  module Filler
    module_function

    PDF_FORMS = PdfForms.new('pdftk')
    FORM_CLASSES = {
      '21P-527EZ' => PdfFill::Forms::VA21P527EZ
    }

    def fill_form(code, form_data)
      form_mod = FORM_CLASSES[code]
      folder = 'tmp/pdfs'
      FileUtils.mkdir_p(folder)
      file_path = "#{folder}/#{code}_#{Time.now}.pdf"

      PDF_FORMS.fill_form(
        "lib/pdf_fill/forms/pdfs/#{code}.pdf",
        file_path,
        HashConverter.new.transform_data(
          form_data: form_mod.merge_fields(form_data),
          pdftk_keys: form_mod::KEY
        )
      )

      file_path
    end
  end
end
