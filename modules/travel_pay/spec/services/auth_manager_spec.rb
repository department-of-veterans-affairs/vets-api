# frozen_string_literal: true

require 'rails_helper'

describe TravelPay::AuthManager do
  context 'get_tokens' do
    let(:user) { build(:user) }
    let(:tokens) do
      {
        veis_token: 'fake_veis_token',
        btsss_token: 'fake_btsss_token'
      }
    end
    let(:cached_tokens) do
      {
        account_uuid: user.account_uuid,
        veis_token: 'cached_veis_token',
        btsss_token: 'cached_btsss_token'
      }
    end
    let(:tokens_response) do
      Faraday::Response.new(
        body: tokens
      )
    end

    context 'authorize' do
      it 'returns a hash with a veis_token and a btsss_token and stores it in the cache' do
        client_number = 123

        allow_any_instance_of(TravelPay::TokenClient)
          .to receive(:request_veis_token)
          .and_return(tokens[:veis_token])
        allow_any_instance_of(TravelPay::TokenClient)
          .to receive(:request_btsss_token)
          .with(tokens[:veis_token], user)
          .and_return(tokens[:btsss_token])

        service = TravelPay::AuthManager.new(client_number, user)
        response = service.authorize
        expect(response).to eq(tokens)
        # Verify that the tokens were stored
        expect($redis.ttl("travel-pay-store:#{user.account_uuid}")).to eq(3300)
        saved_tokens = $redis.get("travel-pay-store:#{user.account_uuid}")
        # The Oj.load method is normally handled by the RedisStore
        Oj.load(saved_tokens) => { veis_token:, btsss_token: }
        destructured_tokens = { veis_token:, btsss_token: }
        expect(destructured_tokens).to eq(tokens)
      end
    end

    context 'uses cached tokens' do
      before do
        $redis.set("travel-pay-store:#{user.account_uuid}", Oj.dump(cached_tokens))
      end

      it 'returns a cached veis_token and btsss_token' do
        client_number = 123
        service = TravelPay::AuthManager.new(client_number, user)
        response = service.authorize
        cached_tokens => { veis_token:, btsss_token: }
        destructured_cached_tokens = { veis_token:, btsss_token: }
        expect(response).to eq(destructured_cached_tokens)
      end
    end
  end
end
