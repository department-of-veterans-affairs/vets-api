# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'TravelPay::Claims', type: :request do
  let(:user) { build(:user) }

  before do
    sign_in(user)
  end

  describe '#index' do
    context 'successful response from API' do
      let(:expected_claim_ids) do
        %w[
          claim_id_1
          claim_id_2
          claim_id_3
        ]
      end

      it 'responds with 200' do
        VCR.use_cassette('travel_pay/200_claims', match_requests_on: %i[method path]) do
          get '/travel_pay/claims', params: nil, headers: { 'Authorization' => 'Bearer vagov_token' }
          expect(response).to have_http_status(:ok)
          claim_ids = JSON.parse(response.body)['data'].pluck('id')
          expect(claim_ids).to eq(expected_claim_ids)
        end
      end
    end

    context 'unsuccessful response from API' do
      it 'responds with a 404 if the API endpoint is not found' do
        VCR.use_cassette('travel_pay/404_claims', match_requests_on: %i[method path]) do
          get '/travel_pay/claims', params: nil, headers: { 'Authorization' => 'Bearer vagov_token' }
          expect(response).to have_http_status(:bad_request)
        end
      end
    end
  end
end
