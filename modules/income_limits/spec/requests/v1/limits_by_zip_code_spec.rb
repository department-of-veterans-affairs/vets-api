# frozen_string_literal: true

# rubocop:disable Layout/LineLength

require 'rails_helper'

RSpec.describe 'IncomeLimits::V1::IncomeLimitsController', type: :request do
  describe 'GET #index' do
    def parse_response(response)
      JSON.parse(response.body)['data']
    end

    context 'with valid parameters' do
      let(:zip) { '15222' }
      let(:year) { '2021' }
      let(:dependents) { '2' }

      before do
        income_threshold_data = FactoryBot.create(:std_income_threshold)
        zipcode_data = FactoryBot.create(:std_zipcode, zip_code: zip)
        state_data = FactoryBot.create(:std_state, id: zipcode_data.state_id)
        county_data = FactoryBot.create(:std_county, county_number: zipcode_data.county_number,
                                                     state_id: zipcode_data.state_id)
        gmt_threshold_data = FactoryBot.create(:gmt_threshold, state_name: state_data.name,
                                                               county_name: "#{county_data.name} county", effective_year: income_threshold_data.income_threshold_year)

        allow(StdIncomeThreshold).to receive(:find_by).and_return(income_threshold_data)
        allow(StdZipcode).to receive(:find_by).and_return(zipcode_data)
        allow(StdState).to receive(:find_by).and_return(state_data)
        allow(StdCounty).to receive(:where).and_return(double(first: county_data))

        allow(GmtThreshold).to receive(:where)
          .with('lower(state_name) = ? AND lower(county_name) LIKE ?', state_data.name.downcase, "#{county_data.name.downcase}%")
          .and_return(GmtThreshold)
        allow(GmtThreshold).to receive(:where)
          .with(effective_year: income_threshold_data.income_threshold_year)
          .and_return(GmtThreshold)
        allow(GmtThreshold).to receive(:order)
          .with(trhd1: :desc)
          .and_return(GmtThreshold)
        allow(GmtThreshold).to receive(:first)
          .and_return(gmt_threshold_data)

        get "/income_limits/v1/limitsByZipCode/#{zip}/#{year}/#{dependents}"
      end

      it 'returns a successful response with accurate data' do
        expect(response).to have_http_status(:ok)
      end

      it 'Returns pennsion threshold data' do
        data = parse_response(response)
        expect(data['pension_threshold']).to eq(20_625)
      end

      it 'Returns national threshold data' do
        data = parse_response(response)
        expect(data['national_threshold']).to eq(43_921)
      end

      it 'Returns gmt threshold data' do
        data = parse_response(response)
        expect(data['gmt_threshold']).to eq(59_800)
      end
    end

    context 'Valid params with more zip with leading 0' do
      let(:zip) { '01020' }
      let(:year) { '2019' }
      let(:dependents) { '7' }

      before do
        income_threshold_data = FactoryBot.create(:std_income_threshold_0_variant)
        zipcode_data = FactoryBot.create(:std_zipcode_0_variant, zip_code: zip)
        state_data = FactoryBot.create(:std_state_0_variant, id: zipcode_data.state_id)
        county_data = FactoryBot.create(:std_county_0_variant, county_number: zipcode_data.county_number,
                                                               state_id: zipcode_data.state_id)
        gmt_threshold_data = FactoryBot.create(:gmt_threshold_0_variant, state_name: state_data.name,
                                                                         county_name: "#{county_data.name} county", effective_year: income_threshold_data.income_threshold_year)

        allow(StdIncomeThreshold).to receive(:find_by).and_return(income_threshold_data)
        allow(StdZipcode).to receive(:find_by).and_return(zipcode_data)
        allow(StdState).to receive(:find_by).and_return(state_data)
        allow(StdCounty).to receive(:where).and_return(double(first: county_data))

        allow(GmtThreshold).to receive(:where)
          .with('lower(state_name) = ? AND lower(county_name) LIKE ?', state_data.name.downcase, "#{county_data.name.downcase}%")
          .and_return(GmtThreshold)
        allow(GmtThreshold).to receive(:where)
          .with(effective_year: income_threshold_data.income_threshold_year)
          .and_return(GmtThreshold)
        allow(GmtThreshold).to receive(:order)
          .with(trhd1: :desc)
          .and_return(GmtThreshold)
        allow(GmtThreshold).to receive(:first)
          .and_return(gmt_threshold_data)

        get "/income_limits/v1/limitsByZipCode/#{zip}/#{year}/#{dependents}"
      end

      it 'returns a successful response with accurate data' do
        expect(response).to have_http_status(:ok)
      end

      it 'Returns pennsion threshold data' do
        data = parse_response(response)
        expect(data['pension_threshold']).to eq(31_602)
      end

      it 'Returns national threshold data' do
        data = parse_response(response)
        expect(data['national_threshold']).to eq(54_237)
      end

      it 'Returns gmt threshold data' do
        data = parse_response(response)
        expect(data['gmt_threshold']).to eq(85_250)
      end
    end

    context 'with invalid parameters' do
      let(:zip) { '15212' }
      let(:year) { '9999' }
      let(:dependents) { '2' }

      before do
        income_threshold_data = FactoryBot.create(:std_income_threshold)
        zipcode_data = FactoryBot.create(:std_zipcode, zip_code: zip)
        state_data = FactoryBot.create(:std_state, id: zipcode_data.state_id)
        county_data = FactoryBot.create(:std_county, county_number: zipcode_data.county_number,
                                                     state_id: zipcode_data.state_id)
        gmt_threshold_data = FactoryBot.create(:gmt_threshold, state_name: state_data.name,
                                                               county_name: "#{county_data.name} county", effective_year: income_threshold_data.income_threshold_year)

        allow(StdIncomeThreshold).to receive(:find_by).and_return(income_threshold_data)
        allow(StdZipcode).to receive(:find_by).and_return(zipcode_data)
        allow(StdState).to receive(:find_by).and_return(state_data)
        allow(StdCounty).to receive(:where).and_return(double(first: county_data))

        allow(GmtThreshold).to receive(:where)
          .with('lower(state_name) = ? AND lower(county_name) LIKE ?', state_data.name.downcase, "#{county_data.name.downcase}%")
          .and_return(GmtThreshold)
        allow(GmtThreshold).to receive(:where)
          .with(effective_year: income_threshold_data.income_threshold_year)
          .and_return(GmtThreshold)
        allow(GmtThreshold).to receive(:order)
          .with(trhd1: :desc)
          .and_return(GmtThreshold)
        allow(GmtThreshold).to receive(:first)
          .and_return(gmt_threshold_data)

        get "/income_limits/v1/limitsByZipCode/#{zip}/#{year}/#{dependents}"
      end

      it 'returns an unprocessable entity status' do
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'returns an error message for invalid parameters' do
        expect(JSON.parse(response.body)['error']).to eq('Invalid year')
      end
    end

    context 'with invalid zipcode' do
      let(:zip) { '00001' }
      let(:year) { '2022' }
      let(:dependents) { '2' }

      before do
        income_threshold_data = FactoryBot.create(:std_income_threshold)
        zipcode_data = FactoryBot.create(:std_zipcode, zip_code: zip)
        state_data = FactoryBot.create(:std_state, id: zipcode_data.state_id)
        county_data = FactoryBot.create(:std_county, county_number: zipcode_data.county_number,
                                                     state_id: zipcode_data.state_id)
        gmt_threshold_data = FactoryBot.create(:gmt_threshold, state_name: state_data.name,
                                                               county_name: "#{county_data.name} county", effective_year: income_threshold_data.income_threshold_year)

        allow(StdIncomeThreshold).to receive(:find_by).and_return(income_threshold_data)
        allow(StdZipcode).to receive(:find_by).and_return(nil)
        allow(StdState).to receive(:find_by).and_return(state_data)
        allow(StdCounty).to receive(:where).and_return(double(first: county_data))

        allow(GmtThreshold).to receive(:where)
          .with('lower(state_name) = ? AND lower(county_name) LIKE ?', state_data.name.downcase, "#{county_data.name.downcase}%")
          .and_return(GmtThreshold)
        allow(GmtThreshold).to receive(:where)
          .with(effective_year: income_threshold_data.income_threshold_year)
          .and_return(GmtThreshold)
        allow(GmtThreshold).to receive(:order)
          .with(trhd1: :desc)
          .and_return(GmtThreshold)
        allow(GmtThreshold).to receive(:first)
          .and_return(gmt_threshold_data)

        get "/income_limits/v1/limitsByZipCode/#{zip}/#{year}/#{dependents}"
      end

      it 'returns an unprocessable entity status' do
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'returns an error message for invalid zipcode' do
        expect(JSON.parse(response.body)['error']).to eq('Invalid zipcode')
      end
    end
  end
end
# rubocop:enable Layout/LineLength
