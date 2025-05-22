# frozen_string_literal: true

require 'rails_helper'
require 'support/controller_spec_helper'

RSpec.describe V0::Chatbot::TokenController, type: :controller do
  let(:user) { create(:user, :loa3, :accountable, icn: '123498767V234859') }

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
        VCR.use_cassette('chatbot/webchat_token_success') do
          post :create
        end

        expect(response).to have_http_status(:ok)
      end

      it 'returns a token for the bot' do
        VCR.use_cassette('chatbot/webchat_token_success') do
          post :create
        end

        res = JSON.parse(response.body)
        expect(res['token']).to eq(recorded_token)
      end

      it('does not return code') do
        VCR.use_cassette('chatbot/webchat_token_success') do
          post :create
        end

        res = JSON.parse(response.body)

        expect(res).not_to have_key('code')
      end

      it('returns api_session') do
        request.cookies[:api_session] = api_session

        VCR.use_cassette('chatbot/webchat_token_success') do
          post :create
        end

        res = JSON.parse(response.body)

        expect(res['apiSession']).to eq(url_encoded_api_session)
      end

      it('returns conversation id') do
        VCR.use_cassette('chatbot/webchat_token_success') do
          post :create
        end

        res = JSON.parse(response.body)

        expect(res['conversationId']).to eq(conversation_id)
      end

      it('does not crash when api session cookie does not exist') do
        VCR.use_cassette('chatbot/webchat_token_success') do
          post :create
        end

        res = JSON.parse(response.body)

        expect(res['apiSession']).to eq('')
      end
    end

    context 'when external service is unavailable' do
      it 'returns service unavailable' do
        VCR.use_cassette('chatbot/webchat_error') do
          post :create
        end

        expect(response).to have_http_status(:service_unavailable)
      end
    end
  end

  context 'when logged in' do
    let(:test_user) { build(:user) }

    before do
      sign_in_as(user)
    end

    it('returns code') do
      VCR.use_cassette('chatbot/webchat_token_success') do
        post :create
      end

      res = JSON.parse(response.body)

      expect(res['code']).to be_a(String)
    end
  end
end
