# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FormTransformers::BenefitsDiscovery::BaseTransformer do
  let(:form_json) do
    {
      'veteranFullName' => {
        'first' => 'John',
        'last' => 'Doe'
      },
      'veteranSocialSecurityNumber' => '123456789',
      'email' => 'john.doe@example.com'
    }.to_json
  end

  let(:form_hash) do
    {
      'veteranFullName' => {
        'first' => 'Jane',
        'last' => 'Smith'
      },
      'veteranSocialSecurityNumber' => '987654321',
      'email' => 'jane.smith@example.com'
    }
  end

  describe '#initialize' do
    context 'when form_data is a JSON string' do
      it 'parses the JSON string into a hash' do
        transformer = described_class.new(form_json)

        expect(transformer.form).to be_a(Hash)
        expect(transformer.form['veteranFullName']['first']).to eq('John')
      end
    end

    context 'when form_data is already a hash' do
      it 'stores the hash directly' do
        transformer = described_class.new(form_hash)

        expect(transformer.form).to eq(form_hash)
        expect(transformer.form['veteranFullName']['first']).to eq('Jane')
      end
    end

    context 'when form_data is invalid JSON' do
      it 'raises an ArgumentError with helpful message' do
        invalid_json = '{ invalid json'

        expect { described_class.new(invalid_json) }.to raise_error(
          ArgumentError,
          /Invalid JSON form data:/
        )
      end
    end

    context 'when form_data is nil' do
      it 'returns empty hash' do
        transformer = described_class.new(nil)

        expect(transformer.form).to eq({})
      end
    end

    context 'when form_data is empty string' do
      it 'raises an ArgumentError' do
        expect { described_class.new('') }.to raise_error(
          ArgumentError,
          /Invalid JSON form data:/
        )
      end
    end
  end

  describe '#transform' do
    it 'raises NotImplementedError for base class' do
      transformer = described_class.new(form_hash)

      expect { transformer.transform }.to raise_error(
        NotImplementedError,
        'Subclasses must implement transform method'
      )
    end
  end
end
