# frozen_string_literal: true

RSpec.shared_context 'revoke_setup' do
  subject { post(:revoke, params: {}.merge(refresh_token_param).merge(anti_csrf_token_param)) }

  let!(:user) { create(:user) }
  let(:user_uuid) { user.uuid }
  let(:refresh_token_param) { { refresh_token: } }
  let(:refresh_token) { 'example-refresh-token' }
  let(:anti_csrf_token_param) { { anti_csrf_token: } }
  let(:anti_csrf_token) { 'example-anti-csrf-token' }
  let(:enable_anti_csrf) { false }
  let(:user_verification) { user.user_verification }
  let(:user_account) { user.user_account }
  let(:validated_credential) do
    create(:validated_credential, user_verification:, client_config:)
  end
  let(:authentication) { SignIn::Constants::Auth::API }
  let!(:client_config) { create(:client_config, authentication:, anti_csrf:, enforced_terms:) }
  let(:enforced_terms) { nil }
  let(:anti_csrf) { false }

  before { allow(Rails.logger).to receive(:info) }
end
