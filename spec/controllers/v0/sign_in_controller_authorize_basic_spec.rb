# frozen_string_literal: true

require 'rails_helper'
require_relative 'sign_in_controller_shared_examples_spec'

RSpec.describe V0::SignInController, type: :controller do
  include_context 'sign_in_controller_shared_setup'
  include_context 'authorize_setup'

  describe 'GET authorize' do
    context 'when client_id is not given' do
      let(:client_id) { {} }
      let(:client_id_value) { nil }
      let(:expected_error) { 'Client id is not valid' }
      let(:expected_error_json) { { 'errors' => expected_error } }
      let(:expected_error_status) { :bad_request }
      let(:statsd_auth_failure) { SignIn::Constants::Statsd::STATSD_SIS_AUTHORIZE_FAILURE }

      it_behaves_like 'api based error response'
    end

    context 'when client_id is an arbitrary value' do
      let(:client_id_value) { 'some-client-id' }
      let(:expected_error) { 'Client id is not valid' }
      let(:expected_error_json) { { 'errors' => expected_error } }
      let(:expected_error_status) { :bad_request }
      let(:statsd_auth_failure) { SignIn::Constants::Statsd::STATSD_SIS_AUTHORIZE_FAILURE }

      it_behaves_like 'api based error response'
    end

    context 'when client_id maps to a client configuration' do
      let(:client_id_value) { client_config.client_id }
      let(:expected_redirect_uri_param) { { redirect_uri: expected_redirect_uri }.to_query }

      context 'when type param is not given' do
        let(:type) { {} }
        let(:type_value) { nil }
        let(:expected_error) { 'Type is not valid' }

        it_behaves_like 'error response'
      end

      context 'when type param is given but not in client credential_service_providers' do
        let(:type_value) { 'idme' }
        let(:type) { { type: type_value } }
        let(:credential_service_providers) { ['logingov'] }
        let(:expected_error) { 'Type is not valid' }

        it_behaves_like 'error response'
      end
    end
  end
end
