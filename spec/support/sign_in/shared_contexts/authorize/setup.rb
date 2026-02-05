# frozen_string_literal: true

RSpec.shared_context 'authorize_setup' do
  subject { get(:authorize, params: authorize_params) }

  let!(:client_config) do
    create(:client_config, authentication:, pkce:, credential_service_providers:, service_levels:, shared_sessions:)
  end
  let(:client_id_value) { client_config.client_id }
  let(:authentication) { SignIn::Constants::Auth::COOKIE }
  let(:pkce) { true }
  let(:shared_sessions) { false }
  let(:credential_service_providers) { %w[idme logingov mhv] }
  let(:service_levels) { %w[loa1 loa3 ial1 ial2 min] }
  let(:type) { { type: type_value } }
  let(:type_value) { 'some-type' }
  let(:acr) { { acr: acr_value } }
  let(:acr_value) { 'some-acr' }
  let(:code_challenge) { { code_challenge: 'some-code-challenge' } }
  let(:code_challenge_method) { { code_challenge_method: 'some-code-challenge-method' } }
  let(:client_id) { { client_id: client_id_value } }
  let(:scope) { { scope: 'some-scope' } }
  let(:operation) { { operation: operation_value } }
  let(:operation_value) { SignIn::Constants::Auth::AUTHORIZE }
  let(:client_state) { {} }
  let(:client_state_minimum_length) { SignIn::Constants::Auth::CLIENT_STATE_MINIMUM_LENGTH }
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
  let(:statsd_tags) do
    ["type:#{type_value}", "client_id:#{client_id_value}", "acr:#{acr_value}", "operation:#{operation_value}"]
  end

  before { allow(Rails.logger).to receive(:info) }
end
