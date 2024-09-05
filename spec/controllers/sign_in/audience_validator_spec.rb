# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SignIn::AudienceValidator do
  controller(ApplicationController) do
    validates_access_token_audience 'web123', 'mobile123'

    def index
      head :ok
    end
  end

  let(:web_client_id) { 'web123' }
  let(:mobile_client_id) { 'mobile123' }
  let(:invalid_client_id) { 'invalid' }

  let(:valid_access_token) { create(:access_token, audience: [web_client_id, mobile_client_id]) }
  let(:invalid_access_token) { create(:access_token, audience: [invalid_client_id]) }
  let!(:user) { create(:user, :loa3, uuid: valid_access_token.user_uuid) }
  let(:access_token_cookie) { SignIn::AccessTokenJwtEncoder.new(access_token: valid_access_token).perform }

  describe '#authenticate' do
    before do
      request.cookies[SignIn::Constants::Auth::ACCESS_TOKEN_COOKIE_NAME] = access_token_cookie
    end

    context 'with a valid audience' do
      it 'allows access' do
        get :index
        expect(response).to have_http_status(:ok)
      end
    end

    context 'with an invalid audience' do
      let(:access_token_cookie) { SignIn::AccessTokenJwtEncoder.new(access_token: invalid_access_token).perform }
      let(:expected_log_message) { '[SignIn][AudienceValidator] Invalid audience' }
      let(:expected_log_payload) do
        { invalid_audience: invalid_access_token.audience, valid_audience: valid_access_token.audience }
      end
      let(:expected_response_body) do
        { errors: 'Invalid audience' }.to_json
      end

      before do
        allow(Rails.logger).to receive(:error)
      end

      it 'denies access' do
        get :index
        expect(response).to have_http_status(:unauthorized)
        expect(response.body).to eq(expected_response_body)
        expect(Rails.logger).to have_received(:error).with(expected_log_message, expected_log_payload)
      end
    end

    context 'when controller has no audience validation' do
      let(:access_token_cookie) { SignIn::AccessTokenJwtEncoder.new(access_token: invalid_access_token).perform }

      controller(SignIn::ApplicationController) do
        def index
          head :ok
        end
      end

      it 'allows access to all audiences' do
        get :index
        expect(response).to have_http_status(:ok)
      end
    end
  end
end
