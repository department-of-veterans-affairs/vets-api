# frozen_string_literal: true

require 'rails_helper'
require 'debts_api/v0/fsr_form_transform/gmt_calculator'

RSpec.describe DebtsApi::V0::FsrFormTransform::GmtCalculator, type: :service do
  describe '#initialize' do
    let(:zip) { '15222' }
    let(:year) { '2021' }
    let(:dependents) { '2' }

    before do
      income_threshold_data = create(:std_income_threshold)
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
    end

    it 'calulates pension threshold' do
      calculator = described_class.new(year:, dependents:, zipcode: zip)
      expect(calculator.pension_threshold).to eq(20_625)
    end

    it 'calculates national threshold' do
      calculator = described_class.new(year:, dependents:, zipcode: zip)
      expect(calculator.national_threshold).to eq(43_921)
    end

    it 'calculates gmt threshold' do
      calculator = described_class.new(year:, dependents:, zipcode: zip)
      expect(calculator.gmt_threshold).to eq(59_800)
    end

    it 'calculates income limits' do
      calculator = described_class.new(year:, dependents:, zipcode: zip)
      expect(calculator.income_limits[:income_upper_threshold]).to eq(89_700.0)
      expect(calculator.income_limits[:asset_threshold]).to eq(3887.0)
      expect(calculator.income_limits[:discretionary_income_threshold]).to eq(747.5)
    end
  end
end
