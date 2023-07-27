# frozen_string_literal: true

require 'rails_helper'
require 'support/controller_spec_helper'

RSpec.describe V0::VirtualAgentSpeechTokenController, type: :controller do
  describe '#create' do
    let(:recorded_token) do
      'fake_token'
    end

    it('returns a 200 ok status with the token') do
      VCR.use_cassette('virtual_agent/webchat_speech_token_success') do
        post :create
      end

      expect(response).to have_http_status(:ok)
      res = JSON.parse(response.body)
      expect(res['token']).to eq(recorded_token)
    end

    context 'when external service is unavailable' do
      it('returns service unavailable') do
        VCR.use_cassette('virtual_agent/webchat_speech_error') do
          post :create
        end

        expect(response).to have_http_status(:service_unavailable)
      end
    end
  end
end
