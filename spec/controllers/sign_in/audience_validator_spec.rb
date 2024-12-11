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

  let(:session) { create(:oauth_session, user_account:) }
  let(:user_account) { create(:user_account) }
  let(:valid_access_token) do
    create(:access_token, user_uuid: user_account.id, session_handle: session.handle,
                          audience: [web_client_id, mobile_client_id])
  end
  let(:invalid_access_token) do
    create(:access_token, user_uuid: user_account.id, session_handle: session.handle, audience: [invalid_client_id])
  end
  let!(:user) { create(:user, :loa3, uuid: valid_access_token.user_uuid) }
  let(:access_token_cookie) { SignIn::AccessTokenJwtEncoder.new(access_token: valid_access_token).perform }
  let(:find_profile_response) { create(:find_profile_response, profile: build(:mpi_profile, icn: user_account.icn)) }

  describe '#authenticate' do
    before do
      request.cookies[SignIn::Constants::Auth::ACCESS_TOKEN_COOKIE_NAME] = access_token_cookie
      allow_any_instance_of(MPI::Service)
        .to receive(:find_profile_by_identifier)
        .with(identifier: user_account.icn, identifier_type: MPI::Constants::ICN)
        .and_return(find_profile_response)
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
