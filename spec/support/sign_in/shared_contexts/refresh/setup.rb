# frozen_string_literal: true

RSpec.shared_context 'refresh_setup' do
  subject { post(:refresh, params: {}.merge(refresh_token_param).merge(anti_csrf_token_param)) }

  let!(:user) { create(:user, uuid: user_uuid) }
  let(:user_uuid) { user_verification.credential_identifier }
  let(:refresh_token_param) { { refresh_token: } }
  let(:anti_csrf_token_param) { { anti_csrf_token: } }
  let(:refresh_token) { 'some-refresh-token' }
  let(:anti_csrf_token) { 'some-anti-csrf-token' }
  let(:user_verification) { create(:user_verification) }
  let(:user_account) { user_verification.user_account }
  let(:validated_credential) do
    create(:validated_credential, user_verification:, client_config:)
  end
  let(:authentication) { SignIn::Constants::Auth::API }
  let!(:client_config) { create(:client_config, authentication:, anti_csrf:, enforced_terms:) }
  let(:enforced_terms) { nil }
  let(:anti_csrf) { false }
  let(:expected_error_status) { :unauthorized }

  before { allow(Rails.logger).to receive(:info) }
end
