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
      described_class::MARITAL_STATUS.each do |status, value|
        context "when marital status is #{status}" do
          let(:form_data) { { 'maritalStatus' => status } }

          it "merges marital status to #{value}" do
            expect(merged_fields).to include(
              'maritalStatus' => value
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

    describe '#merge_sex' do
      described_class::SEX.each do |sex, value|
        context "when gender is #{sex}" do
          let(:form_data) { { 'gender' => sex } }

          it "merges gender to #{value}" do
            expect(merged_fields).to include(
              'gender' => value
            )
          end
        end
      end

      context 'handles value not found in the map options' do
        let(:form_data) { get_fixture('pdf_fill/10-10EZR/kitchen_sink').merge('gender' => 'invalid') }

        it 'sets gender to nil and logs key and value' do
          expect(Rails.logger).to receive(:error)
            .with('Invalid gender value when filling out 10-10EZR pdf.',
                  { type: 'gender', value: form_data['gender'] })

          expect(merged_fields).to include(
            'gender' => nil
          )
        end
      end
    end

    describe '#merge_provide_support_last_year' do
      context 'spouse as dependent' do
        let(:form_data) { { 'provideSupportLastYear' => true } }

        it 'merges based on provideSupportLastYear value' do
          expect(merged_fields).to include(
            'provideSupportLastYear' => 'YES'
          )
        end

        context 'and one child dependent' do
          let(:form_data) do
            { 'dependents' => [{ 'receivedSupportLastYear' => false }], 'provideSupportLastYear' => true }
          end

          it 'merges based on provideSupportLastYear value and dependent receivedSupportLastYear' do
            expect(merged_fields).to include(
              'provideSupportLastYear' => 'YES'
            )
            expect(merged_fields['dependents'].first).to include(
              'receivedSupportLastYear' => 'NO'
            )
          end
        end

        context 'and more than one child dependent' do
          let(:form_data) do
            { 'dependents' => [
              { 'receivedSupportLastYear' => false },
              { 'receivedSupportLastYear' => false }
            ], 'provideSupportLastYear' => false }
          end

          it 'merges based on provideSupportLastYear value and dependent receivedSupportLastYear' do
            expect(merged_fields).to include(
              'provideSupportLastYear' => 'NO'
            )
            expect(merged_fields['dependents'].first).to include(
              'receivedSupportLastYear' => 'NO'
            )
            expect(merged_fields['dependents'].second).to include(
              'receivedSupportLastYear' => 'NO'
            )
          end
        end
      end

      context 'only child as dependent' do
        let(:form_data) do
          { 'dependents' => [
            { 'receivedSupportLastYear' => true }
          ] }
        end

        it 'merges based on dependent receivedSupportLastYear' do
          expect(merged_fields).to include(
            'provideSupportLastYear' => 'YES'
          )
          expect(merged_fields['dependents'].first).to include(
            'receivedSupportLastYear' => 'YES'
          )
        end
      end
    end

    describe 'dependentRelation for one dependent' do
      described_class::DEPENDENT_RELATIONSHIP.each do |relationship, value|
        context "when dependent relationship is #{relationship}" do
          let(:form_data) { { 'dependents' => [{ 'dependentRelation' => relationship }] } }

          it "merges relationship to #{value}" do
            expect(merged_fields['dependents'].first).to include(
              'dependentRelation' => value
            )
          end
        end
      end

      context 'when relation is unknown' do
        let(:form_data) do
          get_fixture('pdf_fill/10-10EZR/kitchen_sink').merge(
            { 'dependents' => [{ 'dependentRelation' => 'invalid' }] }
          )
        end

        it 'defaults to OFF' do
          expect(merged_fields['dependents'].first).to include(
            'dependentRelation' => described_class::OFF
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
