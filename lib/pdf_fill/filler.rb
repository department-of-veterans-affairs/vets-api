# frozen_string_literal: true
require 'pdf_fill/forms/va21527'
require 'pdf_fill/hash_converter'

module PdfFill
  module Filler
    module_function

    PDF_FORMS = PdfForms.new('pdftk')
    FORM_CLASSES = {
      '21-527' => PdfFill::Forms::VA21527
    }

    def fill_form(code, data)
      form_mod = FORM_CLASSES[code]
      folder = 'tmp/pdfs'
      FileUtils.mkdir_p(folder)
      file_path = "#{folder}/#{code}_#{Time.now}.pdf"

      PDF_FORMS.fill_form(
        "lib/pdf_fill/forms/pdfs/#{code}.pdf",
        file_path,
        HashConverter.new.transform_data(
          form_data: data,
          pdftk_keys: FORM_CLASSES[code]::KEY
        )
      )

      file_path
    end
  end
end
