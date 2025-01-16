# frozen_string_literal: true

require 'pdf_forms'

module AccreditedRepresentativePortal
  class PdfFormHandler
    attr_reader :pdf, :pdf_path, :output_path

    def initialize(pdf_path, output_path)
      @pdf_path = pdf_path
      @output_path = output_path
      @pdf = PdfForms.new('/opt/homebrew/bin/pdftk')
    end

    def fill_form(field_data)
      @pdf.fill_form(pdf_path, output_path, field_data)
    end

    def extract_data
      @pdf.get_fields(pdf_path).map { |row| { name: row.name, value: row.value } }
    end
  end
end
