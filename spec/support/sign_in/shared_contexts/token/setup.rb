# frozen_string_literal: true

RSpec.shared_context 'token_setup' do
  subject do
    get(:token,
        params: {}
                .merge(code)
                .merge(code_verifier)
                .merge(grant_type)
                .merge(client_assertion)
                .merge(client_assertion_type)
                .merge(assertion)
                .merge(subject_token)
                .merge(subject_token_type)
                .merge(actor_token)
                .merge(actor_token_type)
                .merge(client_id_param))
  end

  let(:user_verification) { create(:user_verification) }
  let(:user_verification_id) { user_verification.id }
  let!(:user) { create(:user, :loa3, user_verification:, user_account: user_verification.user_account) }
  let(:user_uuid) { user_verification.credential_identifier }
  let(:code) { { code: code_value } }
  let(:code_verifier) { { code_verifier: code_verifier_value } }
  let(:grant_type) { { grant_type: grant_type_value } }
  let(:assertion) { { assertion: assertion_value } }
  let(:subject_token) { { subject_token: subject_token_value } }
  let(:subject_token_type) { { subject_token_type: subject_token_type_value } }
  let(:actor_token) { { actor_token: actor_token_value } }
  let(:actor_token_type) { { actor_token_type: actor_token_type_value } }
  let(:client_id_param) { { client_id: client_id_value } }
  let(:assertion_value) { nil }
  let(:subject_token_value) { 'some-subject-token' }
  let(:subject_token_type_value) { 'some-subject-token-type' }
  let(:actor_token_value) { 'some-actor-token' }
  let(:actor_token_type_value) { 'some-actor-token-type' }
  let(:client_id_value) { 'some-client-id' }
  let(:code_value) { 'some-code' }
  let(:code_verifier_value) { 'some-code-verifier' }
  let(:grant_type_value) { SignIn::Constants::Auth::AUTH_CODE_GRANT }
  let(:client_assertion) { { client_assertion: client_assertion_value } }
  let(:client_assertion_type) { { client_assertion_type: client_assertion_type_value } }
  let(:client_assertion_value) { 'some-client-assertion' }
  let(:client_assertion_type_value) { nil }
  let(:type) { nil }
  let(:client_id) { client_config.client_id }
  let(:authentication) { SignIn::Constants::Auth::API }
  let!(:client_config) do
    create(:client_config,
           authentication:,
           anti_csrf:,
           pkce:,
           enforced_terms:,
           shared_sessions:)
  end
  let(:enforced_terms) { nil }
  let(:pkce) { true }
  let(:anti_csrf) { false }
  let(:loa) { nil }
  let(:shared_sessions) { false }
  let(:statsd_token_success) { SignIn::Constants::Statsd::STATSD_SIS_TOKEN_SUCCESS }
  let(:expected_error_status) { :bad_request }

  before { allow(Rails.logger).to receive(:info) }
end
