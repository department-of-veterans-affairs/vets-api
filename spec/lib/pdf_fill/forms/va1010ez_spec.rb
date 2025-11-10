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
    test_data_types: %w[simple kitchen_sink overflow]
  }

  describe '#merge_fields' do
    subject(:merged_fields) { form_class.merge_fields }

    before do
      # create health_facility record used for vaMedicalFacility field on 10-10EZ
      # pdf form merge_fields spec
      create(:health_facility, name: 'Mobile VA Clinic',
                               station_number: '520GA',
                               postal_name: 'AL')
    end

    it 'merges the right fields' do
      expect(merged_fields).to eq(
        get_fixture('pdf_fill/10-10EZ/merge_fields')
      )
    end

    describe '#merge_full_name' do
      let(:veteran_full_name) do
        {
          'first' => 'Indiana',
          'middle' => 'Bill',
          'last' => 'Jones',
          'suffix' => 'II'
        }
      end

      let(:form_data) do
        { 'veteranFullName' => veteran_full_name }
      end

      context 'all fields' do
        it 'displays full name' do
          expect(merged_fields).to include(
            'veteranFullName' => 'Jones, Indiana, Bill II'
          )
        end
      end

      context 'missing suffix' do
        let(:form_data) { { 'veteranFullName' => veteran_full_name.except('suffix') } }

        it 'displays full name' do
          expect(merged_fields).to include(
            'veteranFullName' => 'Jones, Indiana, Bill'
          )
        end
      end

      context 'missing middle' do
        let(:form_data) { { 'veteranFullName' => veteran_full_name.except('middle') } }

        it 'displays full name' do
          expect(merged_fields).to include(
            'veteranFullName' => 'Jones, Indiana II'
          )
        end
      end

      context 'missing middle and suffix' do
        let(:form_data) { { 'veteranFullName' => veteran_full_name.except('middle', 'suffix') } }

        it 'displays full name' do
          expect(merged_fields).to include(
            'veteranFullName' => 'Jones, Indiana'
          )
        end
      end
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
        let(:form_data) { { 'gender' => 'invalid' } }

        it 'sets gender to nil and logs key and value' do
          expect(Rails.logger).to receive(:error)
            .with('Invalid sex value when filling out 10-10EZ pdf.',
                  { type: 'gender', value: form_data['gender'] })

          expect(merged_fields).to include(
            'gender' => nil
          )
        end
      end
    end

    describe '#merge_disclose_financial_info' do
      described_class::DISCLOSE_FINANCIAL_INFORMATION.each do |disclose, value|
        context "when discloseFinancialInformation is #{disclose}" do
          let(:form_data) { { 'discloseFinancialInformation' => disclose } }

          it "merges disclose financial info to #{value}" do
            expect(merged_fields).to include(
              'discloseFinancialInformation' => value
            )
          end
        end
      end
    end

    describe '#merge_service_connected_rating' do
      described_class::DISABILITY_STATUS.each do |statuses, value|
        statuses.each do |status|
          context "when vaCompensationType is #{status}" do
            let(:form_data) { { 'vaCompensationType' => status } }

            it "merges vaCompensationType to #{value}" do
              expect(merged_fields).to include(
                'vaCompensationType' => value
              )
            end
          end
        end
      end
    end

    describe '#merge_provide_support_last_year' do
      context 'spouse as dependent' do
        let(:form_data) { { 'provideSupportLastYear' => true } }

        it 'merges based on provideSupportLastYear value' do
          expect(merged_fields).to include(
            'provideSupportLastYear' => 1
          )
        end

        context 'and one child dependent' do
          let(:form_data) do
            { 'dependents' => [{ 'receivedSupportLastYear' => false }], 'provideSupportLastYear' => true }
          end

          it 'merges based on provideSupportLastYear value and dependent receivedSupportLastYear' do
            expect(merged_fields).to include(
              'provideSupportLastYear' => 1
            )
            expect(merged_fields['dependents'].first).to include(
              'receivedSupportLastYear' => 'NO'
            )
          end
        end

        context 'and more than one child dependent' do
          context 'where no support was provided' do
            let(:form_data) do
              { 'dependents' => [
                { 'receivedSupportLastYear' => false },
                { 'receivedSupportLastYear' => false }
              ], 'provideSupportLastYear' => false }
            end

            it 'merges based on provideSupportLastYear value and dependent receivedSupportLastYear' do
              expect(merged_fields).to include(
                'provideSupportLastYear' => 2
              )
              expect(merged_fields['dependents'].first).to include(
                'receivedSupportLastYear' => 'NO'
              )
              expect(merged_fields['dependents'].second).to include(
                'receivedSupportLastYear' => 'NO'
              )
            end
          end

          context 'where at least one has support provided' do
            let(:form_data) do
              { 'dependents' => [
                { 'receivedSupportLastYear' => false },
                { 'receivedSupportLastYear' => true }
              ], 'provideSupportLastYear' => false }
            end

            it 'merges based on provideSupportLastYear value and dependent receivedSupportLastYear' do
              expect(merged_fields).to include(
                'provideSupportLastYear' => 1
              )
              expect(merged_fields['dependents'].first).to include(
                'receivedSupportLastYear' => 'NO'
              )
              expect(merged_fields['dependents'].second).to include(
                'receivedSupportLastYear' => 'YES'
              )
            end
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
            'provideSupportLastYear' => 1
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
          get_fixture('pdf_fill/10-10EZ/kitchen_sink').merge(
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
  end
end
