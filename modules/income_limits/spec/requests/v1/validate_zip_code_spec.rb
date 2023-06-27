# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'IncomeLimits::V1::IncomeLimitsController', type: :request do
  describe 'GET #validate_zipcode' do
    def parse_response(response)
      JSON.parse(response.body)
    end

    context 'with valid parameters' do
      let(:zip) { '15222' }

      before do
        zipcode_data = FactoryBot.create(:std_zipcode, zip_code: zip)
        allow(StdZipcode).to receive(:find_by).and_return(zipcode_data)
        get "/income_limits/v1/validateZipCode/#{zip}"
      end

      it 'returns a successful response with accurate data' do
        expect(response).to have_http_status(:ok)
      end

      it 'Validates a valid zip code' do
        data = parse_response(response)
        expect(data['zip_is_valid']).to eq(true)
      end
    end

    context 'with an invalid zip' do
      let(:zip) { '0000' }

      before do
        allow(StdZipcode).to receive(:find_by).and_return(nil)
        get "/income_limits/v1/validateZipCode/#{zip}"
      end

      it 'returns a successful response with accurate data' do
        expect(response).to have_http_status(:ok)
      end

      it 'Returns false when given an invalid zip code' do
        data = parse_response(response)
        expect(data['zip_is_valid']).to eq(false)
      end
    end
  end
end
