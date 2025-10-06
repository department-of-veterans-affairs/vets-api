# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::SignInController, type: :controller do
  include_context 'authorize_setup'

  describe 'GET authorize' do
    context 'when client_id is not given' do
      let(:client_id) { {} }
      let(:client_id_value) { nil }
      let(:expected_error) { 'Client id is not valid' }
      let(:expected_error_json) { { 'errors' => expected_error } }
      let(:expected_error_status) { :bad_request }
      let(:statsd_auth_failure) { SignIn::Constants::Statsd::STATSD_SIS_AUTHORIZE_FAILURE }

      it_behaves_like 'authorize_api_error_response'
    end

    context 'when client_id is an arbitrary value' do
      let(:client_id_value) { 'some-client-id' }
      let(:expected_error) { 'Client id is not valid' }
      let(:expected_error_json) { { 'errors' => expected_error } }
      let(:expected_error_status) { :bad_request }
      let(:statsd_auth_failure) { SignIn::Constants::Statsd::STATSD_SIS_AUTHORIZE_FAILURE }

      it_behaves_like 'authorize_api_error_response'
    end

    context 'when client_id maps to a client configuration' do
      let(:client_id_value) { client_config.client_id }
      let(:expected_redirect_uri_param) { { redirect_uri: expected_redirect_uri }.to_query }

      context 'when type param is not given' do
        let(:type) { {} }
        let(:type_value) { nil }
        let(:expected_error) { 'Type is not valid' }

        it_behaves_like 'authorize_error_response'
      end

      context 'when type param is given but not in client credential_service_providers' do
        let(:type_value) { 'idme' }
        let(:type) { { type: type_value } }
        let(:credential_service_providers) { ['logingov'] }
        let(:expected_error) { 'Type is not valid' }

        it_behaves_like 'authorize_error_response'
      end
    end

    context 'cerner eligibility check' do
      let(:client_id_value) { client_config.client_id }
      let(:type_value) { 'idme' }
      let(:acr_value) { 'loa3' }
      let(:expected_log_message) { '[SignInService] [V0::SignInController] check_cerner_eligibility' }
      let(:expected_log_payload) { { eligible:, cookie_action: } }

      before do
        cookies[SignIn::Constants::Auth::ACCESS_TOKEN_COOKIE_NAME] = 'some-token'
        allow(Rails.logger).to receive(:info)
      end

      context 'when cerner eligible cookie is present' do
        let(:cookie_action) { :found }

        before do
          cookies.signed[V0::SignInController::CERNER_ELIGIBLE_COOKIE_NAME] = eligible.to_s
        end

        context 'when cerner eligible cookie is true' do
          let(:eligible) { true }

          it 'logs the cerner eligibility' do
            subject

            expect(Rails.logger).to have_received(:info).with(expected_log_message, expected_log_payload)
          end
        end

        context 'when cerner eligible cookie is false' do
          let(:eligible) { false }

          it 'logs the cerner eligibility' do
            subject

            expect(Rails.logger).to have_received(:info).with(expected_log_message, expected_log_payload)
          end
        end
      end

      context 'when cerner eligible cookie is not present' do
        let(:cookie_action) { :not_found }
        let(:eligible) { :unknown }

        before do
          cookies.delete(V0::SignInController::CERNER_ELIGIBLE_COOKIE_NAME)
        end

        it 'logs the cerner eligibility' do
          subject

          expect(Rails.logger).to have_received(:info).with(expected_log_message, expected_log_payload)
        end
      end
    end
  end
end
