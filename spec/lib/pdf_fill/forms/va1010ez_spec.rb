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

    describe '#merge_planned_facility_label_helper' do
      before do
        create(:health_facility, name: 'VA Facility Name',
                                 station_number: '100',
                                 postal_name: 'OH')
      end

      context 'plannedClinic is not in health_facilities table' do
        let(:form_data) do
          {
            'vaMedicalFacility' => '99'
          }
        end

        it 'sets the plannedClinic to the facility id' do
          form_class.send(:merge_planned_facility_label_helper)
          expect(form_class.form_data['vaMedicalFacility']).to eq '99'
        end
      end

      context 'plannedClinic is in health_facilities table' do
        let(:form_data) do
          {
            'vaMedicalFacility' => '100'
          }
        end

        it 'sets the plannedClinic to facility id and facility name' do
          form_class.send(:merge_planned_facility_label_helper)
          expect(form_class.form_data['vaMedicalFacility']).to eq '100 - VA Facility Name'
        end
      end
    end
  end
end
