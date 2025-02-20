# frozen_string_literal: true

require 'rails_helper'
require 'pdf_fill/forms/va1010ez'
require 'lib/pdf_fill/fill_form_examples'

describe PdfFill::Forms::Va1010ez do
  include SchemaMatchers

  let(:form_data) do
    get_fixture('pdf_fill/10-10EZ/kitchen_sink')
  end

  let(:form_class) do
    described_class.new(form_data)
  end

  it_behaves_like 'a form filler', {
    form_id: described_class::FORM_ID,
    factory: :health_care_application,
    input_data_fixture_dir: 'spec/fixtures/pdf_fill/10-10EZ',
    output_pdf_fixture_dir: 'spec/fixtures/pdf_fill/10-10EZ/unsigned',
    test_data_types: %w[simple kitchen_sink]
  }

  describe '#merge_fields' do
    it 'merges the right fields' do
      expect(JSON.parse(form_class.merge_fields.to_json)).to eq(
        JSON.parse(get_fixture('pdf_fill/10-10EZ/merge_fields').to_json)
      )
    end

    context 'marital status' do
      described_class::MARITAL_STATUS.each do |status, value|
        context "when marital status is #{status}" do
          let(:form_data) { { 'maritalStatus' => status } }

          it "merges marital status to #{value}" do
            expect(JSON.parse(form_class.merge_fields.to_json)).to include(
              'maritalStatus' => value
            )
          end
        end
      end

      context 'when marital status is unknown' do
        let(:form_data) { { 'maritalStatus' => 'Unknown' } }

        it 'defaults to Off' do
          expect(JSON.parse(form_class.merge_fields.to_json)).to include(
            'maritalStatus' => described_class::OFF
          )
        end
      end
    end

    context 'sex' do
      described_class::SEX.each do |sex, value|
        context "when gender is #{sex}" do
          let(:form_data) { { 'gender' => sex } }

          it "merges gender to #{value}" do
            expect(JSON.parse(form_class.merge_fields.to_json)).to include(
              'gender' => value
            )
          end
        end
      end

      context 'handles value not found in the map options' do
        let(:form_data) { { 'gender' => 'invalid' } }

        it 'sets gender to nil and logs key and value' do
          expect(Rails.logger).to receive(:error)
            .with('Invalid sex value when filling out 10-10EZ pdf.',
                  { type: 'gender', value: form_data['gender'] })

          expect(JSON.parse(form_class.merge_fields.to_json)).to include(
            'gender' => nil
          )
        end
      end
    end

    context 'disclose financial info' do
      described_class::DISCLOSE_FINANCIAL_INFORMATION.each do |disclose, value|
        context "when discloseFinancialInformation is #{disclose}" do
          let(:form_data) { { 'discloseFinancialInformation' => disclose } }

          it "merges disclose financial info to #{value}" do
            expect(JSON.parse(form_class.merge_fields.to_json)).to include(
              'discloseFinancialInformation' => value
            )
          end
        end
      end
    end

    context 'disability status' do
      described_class::DISABILITY_STATUS.each do |statuses, value|
        statuses.each do |status|
          context "when vaCompensationType is #{status}" do
            let(:form_data) { { 'vaCompensationType' => status } }

            it "merges vaCompensationType to #{value}" do
              expect(JSON.parse(form_class.merge_fields.to_json)).to include(
                'vaCompensationType' => value
              )
            end
          end
        end
      end
    end
  end
end
