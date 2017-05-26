# frozen_string_literal: true
require 'spec_helper'
require 'pdf_fill/filler'

describe PdfFill::Filler do
  describe '#fill_form' do
    let(:form_data) do
      {
        'vaFileNumber' => "c12345678",
        "veteranFullName" => {
          "first" => "Mark",
          "last" => "Olson"
        }
      }
    end

    it 'should fill the form correctly' do
      form_code = '21P-527EZ'
      expect(form_data.to_json).to match_vets_schema(form_code)
      file_path = described_class.fill_form(form_code, form_data)

      # File.delete(file_path)
    end
  end
end
