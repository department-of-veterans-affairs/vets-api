# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TravelPay::ClaimsController, type: :request do
  let(:user) { build(:user) }

  describe '#index' do
    context 'successful response from API' do
      it 'responds with 200' do
        allow_any_instance_of(TravelPay::Client).to receive(:request_veis_token).and_return('veis_token')
        allow_any_instance_of(TravelPay::Client).to receive(:request_btsss_token).and_return('btsss_token')
        allow_any_instance_of(TravelPay::Client).to receive(:get_claims).and_return([])
        sign_in(user)

        get '/travel_pay/claims', params: nil, headers: { 'Authorization' => 'Bearer token' }

        expect(response).to have_http_status(:ok)
      end
    end
  end
end
