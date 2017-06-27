# frozen_string_literal: true
require 'rails_helper'
require 'pdf_fill/forms/va21p530'

describe PdfFill::Forms::VA21P530 do
  let(:form_data) do
    {}
  end

  subject do
    described_class.new(form_data)
  end

  describe '#split_ssn' do
    subject do
      described_class.new(form_data).split_ssn
    end

    context 'with no ssn' do
      it 'should return nil' do
        expect(subject).to eq(nil)
      end
    end
  end

  describe '#extract_middle_i' do
    context 'with no veteran full name' do
      it 'should return nil' do
        expect(subject.extract_middle_i).to eq(nil)
      end
    end

    context 'with no middle name' do
      let(:form_data) do
        {
          'veteranFullName' => {}
        }
      end

      it 'should return nil' do
        expect(subject.extract_middle_i).to eq(nil)
      end
    end

    context 'with a middle name' do
      let(:form_data) do
        {
          'veteranFullName' => {
            'middle' => 'middle'
          }
        }
      end

      it 'should extract middle initial' do
        expect(subject.extract_middle_i).to eq({
          'middle' => 'middle',
          'middleInitial' => 'm'
        })
      end
    end
  end
end
