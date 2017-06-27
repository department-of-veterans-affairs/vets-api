# frozen_string_literal: true
require 'spec_helper'
require 'pdf_fill/forms/va21p530'

describe PdfFill::Forms::VA21P530 do
  let(:form_data) do
    {}
  end

  subject do
    described_class.new(form_data)
  end

  describe '#extract_middle_i' do
    context 'with no veteran full name' do
      let(:form_data) do
        {}
      end

      it 'should return nil' do
        expect(subject.extract_middle_i).to eq(nil)
      end
    end
  end
end
