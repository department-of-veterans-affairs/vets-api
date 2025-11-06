# frozen_string_literal: true

RSpec.shared_context 'revoke_all_sessions_setup' do
  subject { get(:revoke_all_sessions) }

  let(:access_token) { SignIn::AccessTokenJwtEncoder.new(access_token: access_token_object).perform }
  let(:authorization) { "Bearer #{access_token}" }
  let(:user) { create(:user, :loa3) }
  let(:user_verification) { user.user_verification }
  let(:user_account) { user.user_account }
  let(:user_uuid) { user.uuid }
  let(:oauth_session) { create(:oauth_session, user_account:) }
  let(:access_token_object) do
    create(:access_token, session_handle: oauth_session.handle, user_uuid:)
  end
  let(:oauth_session_count) { SignIn::OAuthSession.where(user_account:).count }
  let(:statsd_success) { SignIn::Constants::Statsd::STATSD_SIS_REVOKE_ALL_SESSIONS_SUCCESS }
  let(:expected_log) { '[SignInService] [V0::SignInController] revoke all sessions' }
  let(:expected_log_params) do
    {
      uuid: access_token_object.uuid,
      user_uuid: access_token_object.user_uuid,
      session_handle: access_token_object.session_handle,
      client_id: access_token_object.client_id,
      audience: access_token_object.audience,
      version: access_token_object.version,
      last_regeneration_time: access_token_object.last_regeneration_time.to_i,
      created_time: access_token_object.created_time.to_i,
      expiration_time: access_token_object.expiration_time.to_i
    }
  end
  let(:expected_status) { :ok }

  before do
    request.headers['Authorization'] = authorization
    allow(Rails.logger).to receive(:info)
  end
end
