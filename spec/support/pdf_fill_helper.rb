# frozen_string_literal: true

module PdfFillHelper
  # Given two paths to (non-flattened) PDFs this will return true
  # if the PDFs have the same values for every field.
  def pdfs_fields_match?(pdf_1_path, pdf_2_path)
    fields = []
    [pdf_1_path, pdf_2_path].each do |pdf|
      fields << simplify_fields(
        pdf_forms.get_fields(pdf)
      )
    end

    fields[0] == fields[1]
  end

  private

  def pdf_forms
    PdfForms.new(Settings.binaries.pdftk)
  end

  def simplify_fields(fields)
    fields.map do |field|
      {
        name: field.name,
        value: field.value
      }
    end
  end
end
