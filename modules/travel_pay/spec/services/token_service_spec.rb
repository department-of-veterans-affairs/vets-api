# frozen_string_literal: true

require 'rails_helper'

describe TravelPay::TokenService do
  context 'get_tokens' do
    let(:user) { build(:user) }
    let(:tokens) do
      {
        veis_token => 'veis_token',
        btsss_token => 'btsss_token'
      }
    end
    let(:tokens_response) do
      Faraday::Response.new(
        body: tokens
      )
    end

    before do
      allow_any_instance_of(TravelPay::TokenClient)
        .to receive(:get_tokens)
        .with(user)
        .and_return(tokens_response)
    end
  end
end
