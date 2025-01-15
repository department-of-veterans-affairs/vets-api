# frozen_string_literal: true

require 'rails_helper'
require 'debts_api/v0/fsr_form_transform/streamlined_calculator'

RSpec.describe DebtsApi::V0::FsrFormTransform::StreamlinedCalculator, type: :service do
  describe '#initialize' do
    def get_streamlined_data
      transformer = described_class.new(pre_data)
      @data = transformer.get_streamlined_data
    end

    describe '#get_streamlined_data' do
      let(:pre_data) do
        get_fixture_absolute('modules/debts_api/spec/fixtures/pre_submission_fsr/pre_transform')
      end
      let(:expected_post_streamlined_data) do
        get_fixture_absolute('modules/debts_api/spec/fixtures/pre_submission_fsr/post_transform')['streamlined']
      end

      let(:raw_year) { pre_data['personal_data']['veteran_contact_information']['address']['created_at'] }
      let(:zip) { pre_data['personal_data']['veteran_contact_information']['address']['zip_code'] }
      let(:year) { raw_year.to_datetime.year }
      let(:dependents) { pre_data['questions']['has_dependents'] }

      before do
        income_threshold_data = create(:std_income_threshold, income_threshold_year: 2019)
        zipcode_data = create(:std_zipcode, zip_code: zip)
        state_data = create(:std_state, id: zipcode_data.state_id)
        county_data = create(:std_county, county_number: zipcode_data.county_number,
                                          state_id: zipcode_data.state_id)
        gmt_threshold_data = create(:gmt_threshold,
                                    state_name: state_data.name,
                                    county_name: "#{county_data.name} county",
                                    effective_year: income_threshold_data.income_threshold_year)
        state_fips_code = state_data.fips_code
        county_number = format('%03d', county_data.county_number)
        county_indentifier = state_fips_code.to_s + county_number.to_s
        allow(StdIncomeThreshold).to receive(:find_by).and_return(income_threshold_data)
        allow(StdZipcode).to receive(:find_by).and_return(zipcode_data)
        allow(StdState).to receive(:find_by).and_return(state_data)
        allow(StdCounty).to receive(:where).and_return(double(first: county_data))

        allow(GmtThreshold).to receive(:where)
          .with(fips: county_indentifier)
          .and_return(GmtThreshold)
        allow(GmtThreshold).to receive(:where)
          .with(effective_year: income_threshold_data.income_threshold_year)
          .and_return(GmtThreshold)
        allow(GmtThreshold).to receive(:order)
          .with(trhd1: :desc)
          .and_return(GmtThreshold)
        allow(GmtThreshold).to receive(:first)
          .and_return(gmt_threshold_data)

        allow(StatsD).to receive(:increment).and_call_original

        get_streamlined_data
      end

      it 'gets streamlined data correct' do
        expect(expected_post_streamlined_data).to eq(@data)
      end

      context 'with data that should return non-streamlined' do
        let(:pre_data) do
          get_fixture_absolute('modules/debts_api/spec/fixtures/pre_submission_fsr/pre_transform_non_streamlined')
        end
        let(:expected_post_streamlined_data) do
          {
            'value' => false,
            'type' => 'none'
          }
        end

        it 'gets streamlined data correct' do
          expect(expected_post_streamlined_data).to eq(@data)
        end
      end

      context 'with data that should return streamlined short form' do
        let(:pre_data) do
          get_fixture_absolute('modules/debts_api/spec/fixtures/pre_submission_fsr/pre_transform_streamlined_short')
        end
        let(:expected_post_streamlined_data) do
          {
            'value' => true,
            'type' => 'short'
          }
        end

        it 'gets streamlined data correct' do
          expect(expected_post_streamlined_data).to eq(@data)
        end
      end

      context 'with data that should return streamlined long form' do
        let(:pre_data) do
          get_fixture_absolute('modules/debts_api/spec/fixtures/pre_submission_fsr/pre_transform_streamlined_long')
        end
        let(:expected_post_streamlined_data) do
          {
            'value' => true,
            'type' => 'long'
          }
        end

        it 'gets streamlined data correct' do
          expect(expected_post_streamlined_data).to eq(@data)
        end
      end
    end
  end
end
