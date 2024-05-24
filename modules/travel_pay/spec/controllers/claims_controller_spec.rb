# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TravelPay::ClaimsController, type: :request do
  let(:user) { build(:user) }

  describe '#index' do
    context 'successful response from API' do
      it 'responds with 200' do
        allow_any_instance_of(TravelPay::Client)
          .to receive(:request_veis_token)
          .and_return('veis_token')

        allow_any_instance_of(TravelPay::Client)
          .to receive(:request_sts_token)
          .and_return('sts_token')

        allow_any_instance_of(TravelPay::Client)
          .to receive(:request_btsss_token)
          .with('veis_token', 'sts_token')
          .and_return('btsss_token')

        allow_any_instance_of(TravelPay::Client)
          .to receive(:get_claims).and_return([])

        sign_in(user)

        get '/travel_pay/claims', params: nil, headers: { 'Authorization' => 'Bearer vagov_token' }

        expect(response).to have_http_status(:ok)
      end
    end

    context 'unsuccessful response from API' do
      it 'responds with a 404 if the API endpoint is not found' do
        allow_any_instance_of(TravelPay::Client)
          .to receive(:request_veis_token)
          .and_return('veis_token')

        allow_any_instance_of(TravelPay::Client)
          .to receive(:request_sts_token)
          .and_return('sts_token')

        allow_any_instance_of(TravelPay::Client)
          .to receive(:request_btsss_token)
          .with('veis_token', 'sts_token')
          .and_return('btsss_token')

        allow_any_instance_of(TravelPay::Client)
          .to receive(:get_claims)
          .and_raise(
            Faraday::ResourceNotFound.new(
              nil,
              { status: 404, body: { 'message' => 'not found' } }
            )
          )

        sign_in(user)

        get '/travel_pay/claims', params: nil, headers: { 'Authorization' => 'Bearer vagov_token' }

        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
