# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::SignInController, type: :controller do
  include_context 'authorize_setup'

  describe 'GET authorize' do
    let(:client_id_value) { client_config.client_id }
    let(:expected_redirect_uri_param) { { redirect_uri: expected_redirect_uri }.to_query }

    shared_context 'a logingov authentication service interface' do
      context 'and acr param is not given' do
        let(:acr) { {} }
        let(:acr_value) { nil }
        let(:expected_error) { 'ACR is not valid' }

        it_behaves_like 'authorize_error_response'
      end

      context 'and acr param is given but not in client service_levels' do
        let(:acr_value) { 'ial1' }
        let(:service_levels) { ['ial2'] }
        let(:expected_error) { 'ACR is not valid' }

        it_behaves_like 'authorize_error_response'
      end

      context 'and acr param is given and in client service_levels but not valid for logingov' do
        let(:acr_value) { 'loa1' }
        let(:expected_error) { 'Invalid ACR for logingov' }

        it_behaves_like 'authorize_error_response'
      end

      context 'and acr param is given and in client service_levels and valid for logingov' do
        let(:acr_value) { 'ial1' }

        context 'and code_challenge_method is not given' do
          let(:code_challenge_method) { {} }

          context 'and client is configured with pkce enabled' do
            let(:pkce) { true }
            let(:expected_error) { 'Code Challenge Method is not valid' }

            it_behaves_like 'authorize_error_response'
          end

          context 'and client is configured with pkce disabled' do
            let(:pkce) { false }

            it_behaves_like 'authorize_client_state_handling'
          end
        end

        context 'and code_challenge_method is S256' do
          let(:code_challenge_method) { { code_challenge_method: 'S256' } }

          context 'and code_challenge is not given' do
            let(:code_challenge) { {} }

            context 'and client is configured with pkce enabled' do
              let(:pkce) { true }
              let(:expected_error) { 'Code Challenge is not valid' }

              it_behaves_like 'authorize_error_response'
            end

            context 'and client is configured with pkce disabled' do
              let(:pkce) { false }

              it_behaves_like 'authorize_client_state_handling'
            end
          end

          context 'and code_challenge is not properly URL encoded' do
            let(:code_challenge) { { code_challenge: '///some+unsafe code+challenge//' } }

            context 'and client is configured with pkce enabled' do
              let(:pkce) { true }
              let(:expected_error) { 'Code Challenge is not valid' }
              let(:expected_error_json) { { 'errors' => expected_error } }

              it_behaves_like 'authorize_error_response'
            end

            context 'and client is configured with pkce disabled' do
              let(:pkce) { false }

              it_behaves_like 'authorize_client_state_handling'
            end
          end

          context 'and code_challenge is properly URL encoded' do
            let(:code_challenge) { { code_challenge: Base64.urlsafe_encode64('some-safe-code-challenge') } }

            it_behaves_like 'authorize_client_state_handling'
          end
        end

        context 'and code_challenge_method is not S256' do
          context 'and client is configured with pkce enabled' do
            let(:pkce) { true }
            let(:expected_error) { 'Code Challenge Method is not valid' }

            it_behaves_like 'authorize_error_response'
          end

          context 'and client is configured with pkce disabled' do
            let(:pkce) { false }

            it_behaves_like 'authorize_client_state_handling'
          end
        end
      end
    end

    context 'when type param is logingov' do
      let(:type_value) { SignIn::Constants::Auth::LOGINGOV }
      let(:expected_redirect_uri) { IdentitySettings.logingov.redirect_uri }

      context 'and operation param is not given' do
        let(:operation) { {} }
        let(:expected_op_value) { '' }

        it_behaves_like 'a logingov authentication service interface'
      end

      context 'and operation param is in OPERATION_TYPES' do
        let(:operation_value) { SignIn::Constants::Auth::OPERATION_TYPES.first }
        let(:expected_op_value) { '' }

        it_behaves_like 'a logingov authentication service interface'
      end

      context 'and operation param is arbitrary' do
        let(:operation_value) { 'some-operation-value' }
        let(:expected_error) { 'Operation is not valid' }

        it_behaves_like 'authorize_error_response'
      end
    end
  end
end
