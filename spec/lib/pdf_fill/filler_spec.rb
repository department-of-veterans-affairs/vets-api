# frozen_string_literal: true
require 'spec_helper'
require 'pdf_fill/filler'

describe PdfFill::Filler do
  describe '#fill_form' do
    it 'should fill the form correctly' do
      file_path = described_class.fill_form('21P-527EZ', {
        'vaFileNumber' => "c12345678"
      })

      # File.delete(file_path)
    end
  end
end
