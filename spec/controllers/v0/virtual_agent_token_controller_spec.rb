# frozen_string_literal: true

require 'rails_helper'
require 'support/controller_spec_helper'

RSpec.describe V0::VirtualAgentTokenController, type: :controller do
  describe '#create' do
    context 'when external service is healthy' do
      context 'when virtual_agent_bot_a toggle is on' do
        let(:recorded_token) do
          'fake.token.bota'
        end

        it 'returns a token for Bot A' do
          expect(Flipper).to receive(:enabled?).with(:virtual_agent_bot_a).and_return(true)

          VCR.use_cassette('virtual_agent/webchat_token_a', :match_requests_on => [:headers, :uri, :method]) do
            post :create
          end

          expect(response).to have_http_status(:ok)

          res = JSON.parse(response.body)
          expect(res['token']).to eq(recorded_token)
        end
      end

      context 'when virtual_agent_bot_a toggle is off' do
        let(:recorded_token) do
          'fake.token.botb'
        end

        it 'returns a token for Bot B' do
          expect(Flipper).to receive(:enabled?).with(:virtual_agent_bot_a).and_return(false)

          VCR.use_cassette('virtual_agent/webchat_token_b', :match_requests_on => [:headers, :uri, :method]) do
            post :create
          end

          expect(response).to have_http_status(:ok)

          res = JSON.parse(response.body)
          expect(res['token']).to eq(recorded_token)
        end
      end
    end

    context 'when external service is unavailable' do
      it 'returns service unavailable' do
        VCR.use_cassette('virtual_agent/webchat_error') do
          post :create
        end

        expect(response).to have_http_status(:service_unavailable)
      end
    end
  end
end
