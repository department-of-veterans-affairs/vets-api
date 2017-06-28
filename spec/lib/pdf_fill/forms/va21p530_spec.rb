# frozen_string_literal: true
require 'rails_helper'
require 'pdf_fill/forms/va21p530'


def basic_class
  PdfFill::Forms::VA21P530.new({})
end

describe PdfFill::Forms::VA21P530 do
  let(:form_data) do
    {}
  end

  subject do
    described_class.new(form_data)
  end

  test_method(
    basic_class,
    'split_phone',
    [
      [
        [{}, nil],
        nil
      ],
      [
        [
          { phone: '1112223333' },
          :phone
        ],
        {"first"=>"111", "second"=>"222", "third"=>"3333"}
      ]
    ]
  )

  describe '#split_ssn' do
    subject do
      described_class.new(form_data).split_ssn
    end

    context 'with no ssn' do
      it 'should return nil' do
        expect(subject).to eq(nil)
      end
    end

    context 'with a ssn' do
      let(:form_data) do
        {
          'veteranSocialSecurityNumber' => '111223333'
        }
      end

      it 'should split the ssn' do
        expect(subject).to eq({"first"=>"111", "second"=>"22", "third"=>"3333"})
      end
    end
  end

  describe '#extract_middle_i' do
    subject do
      described_class.new(form_data).extract_middle_i(form_data, 'veteranFullName')
    end

    context 'with no veteran full name' do
      it 'should return nil' do
        expect(subject).to eq(nil)
      end
    end

    context 'with no middle name' do
      let(:form_data) do
        {
          'veteranFullName' => {}
        }
      end

      it 'should return nil' do
        expect(subject).to eq(nil)
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
        expect(subject).to eq({
          'middle' => 'middle',
          'middleInitial' => 'm'
        })
      end
    end
  end
end
