# frozen_string_literal: true

RSpec.shared_context 'logout_setup' do
  subject { get(:logout, params: logout_params) }

  let(:logout_params) do
    {}.merge(client_id)
  end
  let(:client_id) { { client_id: client_id_value } }
  let(:client_id_value) { client_config.client_id }
  let!(:client_config) { create(:client_config, logout_redirect_uri:) }
  let(:logout_redirect_uri) { 'some-logout-redirect-uri' }
  let(:access_token) { SignIn::AccessTokenJwtEncoder.new(access_token: access_token_object).perform }
  let(:authorization) { "Bearer #{access_token}" }
  let(:oauth_session) { create(:oauth_session, user_verification:) }
  let(:user_verification) { create(:user_verification) }
  let(:access_token_object) do
    create(:access_token, session_handle: oauth_session.handle, client_id: client_config.client_id, expiration_time:)
  end
  let(:expiration_time) { Time.zone.now + SignIn::Constants::AccessToken::VALIDITY_LENGTH_SHORT_MINUTES }

  before do
    request.headers['Authorization'] = authorization
    allow(Rails.logger).to receive(:info)
  end
end
