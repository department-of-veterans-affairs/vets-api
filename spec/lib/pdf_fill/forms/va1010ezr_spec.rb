# frozen_string_literal: true

require 'rails_helper'
require 'pdf_fill/forms/va1010ezr'
require 'lib/pdf_fill/fill_form_examples'

describe PdfFill::Forms::Va1010ezr do
  include SchemaMatchers

  let(:form_data) do
    get_fixture('pdf_fill/10-10EZR/simple')
  end

  let(:form_class) do
    described_class.new(form_data)
  end

  it_behaves_like 'a form filler', {
    form_id: described_class::FORM_ID,
    factory: :fake_saved_claim,
    input_data_fixture_dir: 'spec/fixtures/pdf_fill/10-10EZR',
    output_pdf_fixture_dir: 'spec/fixtures/pdf_fill/10-10EZR/unsigned',
    test_data_types: %w[simple]
  }

  describe '#merge_fields' do
    it 'merges the right fields' do
      expect(form_class.merge_fields.to_json).to eq(
        get_fixture('pdf_fill/10-10EZR/merge_fields').to_json
      )
    end

    context 'when veteran personal information is missing' do
      let(:form_data) do
        get_fixture('pdf_fill/10-10EZR/simple_with_invalid_values')
      end

      it 'logs an error for each missing value' do
        %w[veteranFullName veteranDateOfBirth veteranSocialSecurityNumber gender].each do |type|
          expect(Rails.logger).to receive(:error).with(
            "Invalid #{type} value when filling out 10-10EZR pdf.",
            {
              type:,
              value: nil
            }
          )
        end
        
        described_class.new(
          get_fixture('pdf_fill/10-10EZR/simple_with_missing_veteran_info')
        ).merge_fields
      end
    end
  end
end
