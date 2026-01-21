# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PdfFilenameGenerator do
  let(:dummy_class) do
    Class.new do
      include PdfFilenameGenerator
    end
  end

  let(:instance) { dummy_class.new }

  describe '#file_name_for_pdf' do
    subject { instance.send(:file_name_for_pdf, parsed_form, 'veteranFullName', form_prefix) }

    let(:form_prefix) { '10-10EZ' }

    context 'with full veteran name' do
      let(:parsed_form) do
        {
          'veteranFullName' => {
            'first' => 'John',
            'last' => 'Doe'
          }
        }
      end

      it 'returns filename with form prefix and full name' do
        expect(subject).to eq('10-10EZ_John_Doe.pdf')
      end
    end

    context 'with only first name' do
      let(:parsed_form) do
        {
          'veteranFullName' => {
            'first' => 'John',
            'last' => ''
          }
        }
      end

      it 'returns filename with form prefix and first name only' do
        expect(subject).to eq('10-10EZ_John.pdf')
      end
    end

    context 'with only last name' do
      let(:parsed_form) do
        {
          'veteranFullName' => {
            'first' => '',
            'last' => 'Doe'
          }
        }
      end

      it 'returns filename with form prefix and last name only' do
        expect(subject).to eq('10-10EZ_Doe.pdf')
      end
    end

    context 'with no veteran name' do
      let(:parsed_form) do
        {
          'veteranFullName' => {
            'first' => '',
            'last' => ''
          }
        }
      end

      it 'returns filename with form prefix only' do
        expect(subject).to eq('10-10EZ.pdf')
      end
    end

    context 'with whitespace-only names' do
      let(:parsed_form) do
        {
          'veteranFullName' => {
            'first' => '   ',
            'last' => "\t\n"
          }
        }
      end

      it 'returns filename with form prefix only' do
        expect(subject).to eq('10-10EZ.pdf')
      end
    end

    context 'with nil names' do
      let(:parsed_form) do
        {
          'veteranFullName' => {
            'first' => nil,
            'last' => nil
          }
        }
      end

      it 'returns filename with form prefix only' do
        expect(subject).to eq('10-10EZ.pdf')
      end
    end

    context 'with missing veteranFullName key' do
      let(:parsed_form) do
        {
          'someOtherField' => 'value'
        }
      end

      it 'returns filename with form prefix only' do
        expect(subject).to eq('10-10EZ.pdf')
      end
    end

    context 'with missing first and last keys' do
      let(:parsed_form) do
        {
          'veteranFullName' => {
            'middle' => 'Middle'
          }
        }
      end

      it 'returns filename with form prefix only' do
        expect(subject).to eq('10-10EZ.pdf')
      end
    end

    context 'with empty parsed_form' do
      let(:parsed_form) { {} }

      it 'returns filename with form prefix only' do
        expect(subject).to eq('10-10EZ.pdf')
      end
    end

    context 'with different form prefix' do
      let(:form_prefix) { '10-10EZR' }
      let(:parsed_form) do
        {
          'veteranFullName' => {
            'first' => 'Jane',
            'last' => 'Smith'
          }
        }
      end

      it 'returns filename with specified form prefix' do
        expect(subject).to eq('10-10EZR_Jane_Smith.pdf')
      end
    end

    context 'with special characters in names' do
      let(:parsed_form) do
        {
          'veteranFullName' => {
            'first' => 'John-Paul',
            'last' => "O'Connor"
          }
        }
      end

      it 'preserves special characters in filename' do
        expect(subject).to eq("10-10EZ_John-Paul_O'Connor.pdf")
      end
    end
  end
end
