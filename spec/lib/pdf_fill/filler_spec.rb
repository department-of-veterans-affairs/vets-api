# frozen_string_literal: true
require 'spec_helper'
require 'pdf_fill/filler'

describe PdfFill::Filler do
  describe '#fill_form' do
    it 'should fill the form correctly' do
      described_class.fill_form('21-527', {
        'vaFileNumber' => "c12345678"
      })
    end
  end
end
