# frozen_string_literal: true

require 'rails_helper'
require 'support/controller_spec_helper'

RSpec.describe V0::VirtualAgentTokenMsftController, type: :controller do
  describe '#create' do
    context 'when external service is healthy' do
      let(:api_session) do
        'fake api session'
      end

      let(:url_encoded_api_session) do
        'fake%20api%20session'
      end

      let(:conversation_id) do
        'fake.conversation.id'
      end

      let(:recorded_token) do
        'fake.token.bot'
      end

      it('returns a 200 ok status') do
        VCR.use_cassette('virtual_agent/webchat_token_success') do
          post :create
        end

        expect(response).to have_http_status(:ok)
      end

      it 'returns a token for the bot' do
        VCR.use_cassette('virtual_agent/webchat_token_success') do
          post :create
        end

        res = JSON.parse(response.body)
        expect(res['token']).to eq(recorded_token)
      end

      it('returns api_session') do
        request.cookies[:api_session] = api_session

        VCR.use_cassette('virtual_agent/webchat_token_success') do
          post :create
        end

        res = JSON.parse(response.body)

        expect(res['apiSession']).to eq(url_encoded_api_session)
      end

      it('returns conversation id') do
        VCR.use_cassette('virtual_agent/webchat_token_success') do
          post :create
        end

        res = JSON.parse(response.body)

        expect(res['conversationId']).to eq(conversation_id)
      end

      it('does not crash when api session cookie does not exist') do
        VCR.use_cassette('virtual_agent/webchat_token_success') do
          post :create
        end

        res = JSON.parse(response.body)

        expect(res['apiSession']).to eq('')
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
