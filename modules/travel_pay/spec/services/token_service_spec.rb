# frozen_string_literal: true

require 'rails_helper'

describe TravelPay::TokenService do
  context 'get_tokens' do
    let(:user) { build(:user) }
    let(:tokens) do
      {
        veis_token: 'fake_veis_token',
        btsss_token: 'fake_btsss_token'
      }
    end
    let(:tokens_response) do
      Faraday::Response.new(
        body: tokens
      )
    end

    context 'get_tokens' do
      it 'returns a hash with a veis_token and a btsss_token' do
        allow_any_instance_of(TravelPay::TokenClient)
          .to receive(:request_veis_token)
          .and_return(tokens[:veis_token])
        allow_any_instance_of(TravelPay::TokenClient)
          .to receive(:request_btsss_token)
          .with(tokens[:veis_token], user)
          .and_return(tokens[:btsss_token])

        service = TravelPay::TokenService.new
        response = service.get_tokens(user)
        expect(response).to eq(tokens)
        expect($redis.ttl("travel-pay-store:#{user.account_uuid}")).to eq(3600)
      end
    end
  end
end
