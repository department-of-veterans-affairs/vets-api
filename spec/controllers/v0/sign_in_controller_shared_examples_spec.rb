# frozen_string_literal: true

require 'rails_helper'
require 'sign_in/logingov/service'
require 'sign_in/idme/service'

# =============================================================================
# GENERIC SHARED SETUP (used across multiple routes)
# =============================================================================

RSpec.shared_context 'sign_in_controller_shared_setup' do
  let!(:client_config) do
    create(:client_config, authentication:, pkce:, credential_service_providers:, service_levels:, shared_sessions:)
  end
  let(:acr) { { acr: acr_value } }
  let(:acr_value) { 'some-acr' }
  let(:code_challenge) { { code_challenge: 'some-code-challenge' } }
  let(:code_challenge_method) { { code_challenge_method: 'some-code-challenge-method' } }
  let(:client_id) { { client_id: client_id_value } }
  let(:pkce) { true }
  let(:scope) { { scope: 'some-scope' } }
  let(:shared_sessions) { false }
  let(:credential_service_providers) { %w[idme logingov dslogon mhv] }
  let(:service_levels) { %w[loa1 loa3 ial1 ial2 min] }
  let(:client_id_value) { client_config.client_id }
  let(:authentication) { SignIn::Constants::Auth::COOKIE }
  let(:client_state) { {} }
  let(:client_state_minimum_length) { SignIn::Constants::Auth::CLIENT_STATE_MINIMUM_LENGTH }
  let(:type) { { type: type_value } }
  let(:type_value) { 'some-type' }
  let(:operation) { { operation: operation_value } }
  let(:operation_value) { SignIn::Constants::Auth::AUTHORIZE }

  before { allow(Rails.logger).to receive(:info) }
end

# =============================================================================
# AUTHORIZE ROUTE SHARED EXAMPLES AND CONTEXTS
# =============================================================================

RSpec.shared_context 'authorize_setup' do
  subject { get(:authorize, params: authorize_params) }

  let(:authorize_params) do
    {}.merge(type)
      .merge(code_challenge)
      .merge(code_challenge_method)
      .merge(client_state)
      .merge(client_id)
      .merge(acr)
      .merge(operation)
      .merge(scope)
  end

  let(:client_id_value) { client_config.client_id }

  let(:statsd_tags) do
    ["type:#{type_value}", "client_id:#{client_id_value}", "acr:#{acr_value}", "operation:#{operation_value}"]
  end
end

RSpec.shared_examples 'api based error response' do
  let(:expected_error_json) { { 'errors' => expected_error } }
  let(:expected_error_status) { :bad_request }
  let(:statsd_auth_failure) { SignIn::Constants::Statsd::STATSD_SIS_AUTHORIZE_FAILURE }
  let(:expected_error_log) { '[SignInService] [V0::SignInController] authorize error' }
  let(:expected_error_message) do
    { errors: expected_error, client_id: client_id_value, type: type_value, acr: acr_value }
  end

  it 'renders expected error' do
    expect(JSON.parse(subject.body)).to eq(expected_error_json)
  end

  it 'returns expected status' do
    expect(subject).to have_http_status(expected_error_status)
  end

  it 'logs the failed authorize attempt' do
    expect(Rails.logger).to receive(:info).with(expected_error_log, expected_error_message)
    subject
  end

  it 'updates StatsD with a auth request failure' do
    expect { subject }.to trigger_statsd_increment(statsd_auth_failure)
  end
end

RSpec.shared_examples 'error response' do
  let(:expected_error_json) { { 'errors' => expected_error } }
  let(:expected_error_status) { :bad_request }
  let(:statsd_auth_failure) { SignIn::Constants::Statsd::STATSD_SIS_AUTHORIZE_FAILURE }
  let(:expected_error_log) { '[SignInService] [V0::SignInController] authorize error' }
  let(:expected_error_message) do
    { errors: expected_error, client_id: client_id_value, type: type_value, acr: acr_value }
  end

  context 'and client_id maps to a web based configuration' do
    let(:authentication) { SignIn::Constants::Auth::COOKIE }
    let(:expected_error_status) { :ok }
    let(:error_code) { SignIn::Constants::ErrorCode::INVALID_REQUEST }
    let(:auth_param) { 'fail' }
    let(:request_id) { SecureRandom.uuid }
    let(:meta_refresh_tag) { '<meta http-equiv="refresh" content="0;' }

    before do
      allow_any_instance_of(ActionController::TestRequest).to receive(:request_id).and_return(request_id)
    end

    it 'renders the oauth_get_form template with meta refresh tag' do
      expect(subject.body).to include(meta_refresh_tag)
    end

    it 'directs to the given redirect url set in the client configuration' do
      expect(subject.body).to include(client_config.redirect_uri)
    end

    it 'includes expected auth param' do
      expect(subject.body).to include(auth_param)
    end

    it 'includes expected code param' do
      expect(subject.body).to include(error_code)
    end

    it 'includes expected request_id param' do
      expect(subject.body).to include(request_id)
    end

    it 'returns expected status' do
      expect(subject).to have_http_status(expected_error_status)
    end

    it 'logs the failed authorize attempt' do
      expect(Rails.logger).to receive(:info).with(expected_error_log, expected_error_message)
      subject
    end

    it 'updates StatsD with a auth request failure' do
      expect { subject }.to trigger_statsd_increment(statsd_auth_failure)
    end
  end

  context 'and client_id maps to an api based configuration' do
    let(:authentication) { SignIn::Constants::Auth::API }

    it_behaves_like 'api based error response'
  end
end

RSpec.shared_context 'successful response' do
  it 'returns ok status' do
    expect(subject).to have_http_status(:ok)
  end

  it 'renders expected state' do
    expect(subject.body).to match(state)
  end

  it 'renders expected redirect_uri in template' do
    expect(subject.body).to match(expected_redirect_uri_param)
  end

  it 'renders expected op value in template' do
    expect(subject.body).to match(expected_op_value)
  end

  it 'logs the authentication attempt' do
    expect(Rails.logger).to receive(:info).with(expected_log, expected_logger_context)
    subject
  end

  it 'updates StatsD with a auth request success' do
    expect { subject }.to trigger_statsd_increment(statsd_auth_success, tags: statsd_tags)
  end
end

RSpec.shared_context 'expected response with optional scope' do
  context 'and scope is device_sso' do
    let(:scope) { { scope: SignIn::Constants::Auth::DEVICE_SSO } }

    context 'and client config is not set up to enable device_sso' do
      let(:shared_sessions) { false }
      let(:expected_error) { 'Scope is not valid for Client' }

      it_behaves_like 'error response'
    end

    context 'and client config is set up to enable device_sso' do
      let(:shared_sessions) { true }
      let(:authentication) { SignIn::Constants::Auth::API }

      it_behaves_like 'successful response'
    end
  end

  context 'and scope is not given' do
    let(:scope) { {} }

    it_behaves_like 'successful response'
  end
end

RSpec.shared_context 'expected response with optional client state' do
  let(:state) { 'some-state' }
  let(:statsd_auth_success) { SignIn::Constants::Statsd::STATSD_SIS_AUTHORIZE_SUCCESS }
  let(:expected_log) { '[SignInService] [V0::SignInController] authorize' }
  let(:expected_logger_context) do
    {
      type: type[:type],
      client_id: client_id_value,
      acr: acr_value,
      operation: operation_value
    }
  end

  before { allow(JWT).to receive(:encode).and_return(state) }

  context 'and client_state is not given' do
    let(:client_state) { {} }

    it_behaves_like 'expected response with optional scope'
  end

  context 'and client_state is greater than minimum client state length' do
    let(:client_state) do
      { state: SecureRandom.alphanumeric(SignIn::Constants::Auth::CLIENT_STATE_MINIMUM_LENGTH + 1) }
    end

    it_behaves_like 'expected response with optional scope'
  end

  context 'and client_state is less than minimum client state length' do
    let(:client_state) do
      { state: SecureRandom.alphanumeric(SignIn::Constants::Auth::CLIENT_STATE_MINIMUM_LENGTH - 1) }
    end
    let(:expected_error) { 'Attributes are not valid' }

    it_behaves_like 'error response'
  end
end

# =============================================================================
# CALLBACK ROUTE SHARED EXAMPLES AND CONTEXTS
# =============================================================================

RSpec.shared_context 'callback_setup' do
  subject { get(:callback, params: {}.merge(code).merge(state).merge(error)) }

  let(:code) { { code: code_value } }
  let(:state) { { state: state_value } }
  let(:error) { { error: error_value } }
  let(:state_value) { 'some-state' }
  let(:code_value) { 'some-code' }
  let(:error_value) { 'some-error' }
  let(:statsd_tags) { ["type:#{type}", "client_id:#{client_id}", "ial:#{ial}", "acr:#{acr}"] }
  let(:type) {}
  let(:acr) { nil }
  let(:mpi_update_profile_response) { create(:add_person_response) }
  let(:mpi_add_person_response) { create(:add_person_response, parsed_codes: { icn: add_person_icn }) }
  let(:add_person_icn) { nil }
  let(:find_profile) { create(:find_profile_response, profile: mpi_profile) }
  let(:mpi_profile) { nil }
  let(:client_id) { client_config.client_id }
  let(:authentication) { SignIn::Constants::Auth::API }
  let!(:client_config) { create(:client_config, authentication:, enforced_terms:, terms_of_use_url:) }
  let(:enforced_terms) { nil }
  let(:terms_of_use_url) { 'some-terms-of-use-url' }
  let(:code_challenge) { Base64.urlsafe_encode64('some-code-challenge') }
  let(:code_challenge_method) { SignIn::Constants::Auth::CODE_CHALLENGE_METHOD }
  let(:client_state) { SecureRandom.alphanumeric(SignIn::Constants::Auth::CLIENT_STATE_MINIMUM_LENGTH) }

  before do
    allow(Rails.logger).to receive(:info)
    allow_any_instance_of(MPI::Service).to receive(:update_profile).and_return(mpi_update_profile_response)
    allow_any_instance_of(MPIData).to receive(:response_from_redis_or_service).and_return(find_profile)
    allow_any_instance_of(MPI::Service).to receive(:find_profile_by_identifier).and_return(find_profile)
    allow_any_instance_of(MPI::Service).to receive(:add_person_implicit_search).and_return(mpi_add_person_response)
  end
end

RSpec.shared_examples 'callback api based error response' do
  let(:expected_error_json) { { 'errors' => expected_error } }
  let(:expected_error_status) { :bad_request }
  let(:statsd_callback_failure) { SignIn::Constants::Statsd::STATSD_SIS_CALLBACK_FAILURE }
  let(:expected_error_log) { '[SignInService] [V0::SignInController] callback error' }
  let(:expected_error_message) do
    { errors: expected_error, client_id:, type:, acr: }
  end

  it 'renders expected error' do
    expect(JSON.parse(subject.body)).to eq(expected_error_json)
  end

  it 'returns expected status' do
    expect(subject).to have_http_status(expected_error_status)
  end

  it 'logs the failed callback' do
    expect(Rails.logger).to receive(:info).with(expected_error_log, expected_error_message)
    subject
  end

  it 'updates StatsD with a callback request failure' do
    expect { subject }.to trigger_statsd_increment(statsd_callback_failure)
  end
end

RSpec.shared_examples 'callback error response' do
  let(:expected_error_json) { { 'errors' => expected_error } }
  let(:expected_error_status) { :bad_request }
  let(:statsd_callback_failure) { SignIn::Constants::Statsd::STATSD_SIS_CALLBACK_FAILURE }

  context 'and client_id maps to a web based configuration' do
    let(:authentication) { SignIn::Constants::Auth::COOKIE }
    let(:expected_error_status) { :ok }
    let(:auth_param) { 'fail' }
    let(:expected_error_log) { '[SignInService] [V0::SignInController] callback error' }
    let(:expected_error_message) { { errors: expected_error, client_id:, type:, acr: } }
    let(:request_id) { SecureRandom.uuid }
    let(:meta_refresh_tag) { '<meta http-equiv="refresh" content="0;' }

    before do
      allow_any_instance_of(ActionController::TestRequest).to receive(:request_id).and_return(request_id)
    end

    it 'renders the oauth_get_form template with meta refresh tag' do
      expect(subject.body).to include(meta_refresh_tag)
    end

    it 'directs to the given redirect url set in the client configuration' do
      expect(subject.body).to include(client_config.redirect_uri)
    end

    it 'includes expected auth param' do
      expect(subject.body).to include(auth_param)
    end

    it 'includes expected code param' do
      expect(subject.body).to include(error_code)
    end

    it 'includes expected request_id param' do
      expect(subject.body).to include(request_id)
    end

    it 'returns expected status' do
      expect(subject).to have_http_status(expected_error_status)
    end

    it 'logs the failed callback' do
      expect(Rails.logger).to receive(:info).with(expected_error_log, expected_error_message)
      subject
    end

    it 'updates StatsD with a callback request failure' do
      expect { subject }.to trigger_statsd_increment(statsd_callback_failure)
    end
  end

  context 'and client_id maps to an api based configuration' do
    let(:authentication) { SignIn::Constants::Auth::API }

    it_behaves_like 'callback api based error response'
  end
end
