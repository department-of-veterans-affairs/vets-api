# frozen_string_literal: true

require 'rails_helper'
require_relative '../sign_in_controller_shared_examples_spec'

RSpec.describe V0::SignInController, type: :controller do
  include_context 'sign_in_controller_shared_setup'
  include_context 'authorize_setup'

  describe 'GET authorize' do
    shared_examples 'an idme service interface with appropriate operation' do
      let(:expected_redirect_uri) { IdentitySettings.idme.redirect_uri }
      let(:expected_redirect_uri_param) { { redirect_uri: expected_redirect_uri }.to_query }

      context 'and acr param is not given' do
        let(:acr) { {} }
        let(:acr_value) { nil }
        let(:expected_error) { 'ACR is not valid' }

        it_behaves_like 'error response'
      end

      context 'and acr param is given but not in client service_levels' do
        let(:acr_value) { 'loa1' }
        let(:service_levels) { ['loa3'] }
        let(:expected_error) { 'ACR is not valid' }

        it_behaves_like 'error response'
      end

      context 'and acr param is given and in client service_levels but not valid for type' do
        let(:acr_value) { 'ial1' }
        let(:expected_error) { "Invalid ACR for #{type_value}" }

        it_behaves_like 'error response'
      end

      context 'and acr param is given and in client service_levels and valid for type' do
        let(:acr_value) { 'loa1' }

        context 'and code_challenge_method is not given' do
          let(:code_challenge_method) { {} }

          context 'and client is configured with pkce enabled' do
            let(:pkce) { true }
            let(:expected_error) { 'Code Challenge Method is not valid' }

            it_behaves_like 'error response'
          end

          context 'and client is configured with pkce disabled' do
            let(:pkce) { false }

            it_behaves_like 'expected response with optional client state'
          end
        end

        context 'and code_challenge_method is S256' do
          let(:code_challenge_method) { { code_challenge_method: 'S256' } }

          context 'and code_challenge is not given' do
            let(:code_challenge) { {} }

            context 'and client is configured with pkce enabled' do
              let(:pkce) { true }
              let(:expected_error) { 'Code Challenge is not valid' }

              it_behaves_like 'error response'
            end

            context 'and client is configured with pkce disabled' do
              let(:pkce) { false }

              it_behaves_like 'expected response with optional client state'
            end
          end

          context 'and code_challenge is not properly URL encoded' do
            let(:code_challenge) { { code_challenge: '///some+unsafe code+challenge//' } }

            context 'and client is configured with pkce enabled' do
              let(:pkce) { true }
              let(:expected_error) { 'Code Challenge is not valid' }

              it_behaves_like 'error response'
            end

            context 'and client is configured with pkce disabled' do
              let(:pkce) { false }

              it_behaves_like 'expected response with optional client state'
            end
          end

          context 'and code_challenge is properly URL encoded' do
            let(:code_challenge) { { code_challenge: Base64.urlsafe_encode64('some-safe-code-challenge') } }

            it_behaves_like 'expected response with optional client state'
          end
        end

        context 'and code_challenge_method is not S256' do
          let(:code_challenge_method) { { code_challenge_method: 'some-code-challenge-method' } }

          context 'and client is configured with pkce enabled' do
            let(:pkce) { true }
            let(:expected_error) { 'Code Challenge Method is not valid' }

            it_behaves_like 'error response'
          end

          context 'and client is configured with pkce disabled' do
            let(:pkce) { false }

            it_behaves_like 'expected response with optional client state'
          end
        end
      end
    end

    shared_context 'an idme authentication service interface' do
      context 'and operation param is sign_up' do
        let(:operation_value) { SignIn::Constants::Auth::SIGN_UP }
        let(:expected_op_value) { 'op=signup' }

        it_behaves_like 'an idme service interface with appropriate operation'
      end
    end

    context 'when type param is idme' do
      let(:type_value) { SignIn::Constants::Auth::IDME }
      let(:expected_type_value) { SignIn::Constants::Auth::IDME }

      it_behaves_like 'an idme authentication service interface'
    end
  end
end
