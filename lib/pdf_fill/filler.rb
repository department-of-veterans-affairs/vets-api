# frozen_string_literal: true
require 'pdf_fill/forms/va21p527ez'
require 'pdf_fill/hash_converter'

module PdfFill
  module Filler
    module_function
    # TODO handle array and string overflows

    PDF_FORMS = PdfForms.new('pdftk')
    FORM_CLASSES = {
      '21P-527EZ' => PdfFill::Forms::VA21P527EZ
    }.freeze

    def fill_form(code, form_data)
      form_class = FORM_CLASSES[code]
      folder = 'tmp/pdfs'
      FileUtils.mkdir_p(folder)
      # TODO add the id of the form to filename and remove timestamp
      file_path = "#{folder}/#{code}_#{Time.zone.now}.pdf"

      PDF_FORMS.fill_form(
        "lib/pdf_fill/forms/pdfs/#{code}.pdf",
        file_path,
        HashConverter.new.transform_data(
          form_data: form_class.new(form_data).merge_fields,
          pdftk_keys: form_class::KEY
        )
      )

      file_path
    end
  end
end
