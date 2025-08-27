# frozen_string_literal: true

require 'rails_helper'
require 'pdf_fill/forms/va1010ezr'
require 'lib/pdf_fill/fill_form_examples'

describe PdfFill::Forms::Va1010ezr do
  include SchemaMatchers

  let(:form_data) do
    get_fixture('pdf_fill/10-10EZR/kitchen_sink')
  end

  let(:form_class) do
    described_class.new(form_data)
  end

  it_behaves_like 'a form filler', {
    form_id: described_class::FORM_ID,
    factory: :fake_saved_claim,
    input_data_fixture_dir: 'spec/fixtures/pdf_fill/10-10EZR',
    output_pdf_fixture_dir: 'spec/fixtures/pdf_fill/10-10EZR/unsigned',
    test_data_types: %w[simple kitchen_sink overflow]
  }

  describe '#merge_fields' do
    subject(:merged_fields) { form_class.merge_fields }

    it 'merges the right fields' do
      expect(merged_fields).to eq(
        get_fixture('pdf_fill/10-10EZR/merge_fields')
      )
    end

    describe '#merge_marital_status' do
      ['Divorced', 'Married', 'Never Married', 'Separated', 'Widowed'].each do |status|
        context "when marital status is #{status}" do
          let(:form_data) { { 'maritalStatus' => status } }

          it "merges marital status to uppercase #{status.upcase}" do
            expect(merged_fields).to include(
              'maritalStatus' => status.upcase
            )
          end
        end
      end

      context 'when marital status is unknown' do
        let(:form_data) { { 'maritalStatus' => 'Unknown' } }

        it 'defaults to Off' do
          expect(merged_fields).to include(
            'maritalStatus' => described_class::OFF
          )
        end
      end
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
