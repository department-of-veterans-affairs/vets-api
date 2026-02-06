# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::SignInController, type: :controller do
  include_context 'authorize_setup'

  describe 'GET authorize' do
    let(:expected_redirect_uri_param) { { redirect_uri: expected_redirect_uri }.to_query }

    shared_context 'an idme authentication service interface' do
      context 'and operation param is not given' do
        let(:operation) { {} }
        let(:expected_op_value) { '' }

        it_behaves_like 'an idme service interface with appropriate operation'
      end

      context 'and operation param is authorize' do
        let(:operation_value) { SignIn::Constants::Auth::AUTHORIZE }
        let(:expected_op_value) { '' }

        it_behaves_like 'an idme service interface with appropriate operation'
      end

      context 'and operation param is arbitrary' do
        let(:operation_value) { 'some-operation-value' }
        let(:expected_error) { 'Operation is not valid' }

        it_behaves_like 'authorize_error_response'
      end

      context 'and operation param is sign_up' do
        let(:operation_value) { SignIn::Constants::Auth::SIGN_UP }
        let(:expected_op_value) { 'op=signup' }

        it_behaves_like 'an idme service interface with appropriate operation'
      end

      context 'and the operation param is interstitial_verify' do
        let(:operation_value) { SignIn::Constants::Auth::INTERSTITIAL_VERIFY }
        let(:expected_op_value) { '' }

        it_behaves_like 'an idme service interface with appropriate operation'
      end

      context 'and the operation param is interstitial_signup' do
        let(:operation_value) { SignIn::Constants::Auth::INTERSTITIAL_SIGNUP }
        let(:expected_op_value) { '' }

        it_behaves_like 'an idme service interface with appropriate operation'
      end

      context 'and the operation param is verify_cta_authenticated' do
        let(:operation_value) { SignIn::Constants::Auth::VERIFY_CTA_AUTHENTICATED }
        let(:expected_op_value) { '' }

        it_behaves_like 'an idme service interface with appropriate operation'
      end

      context 'and the operation param is verify_page_authenticated' do
        let(:operation_value) { SignIn::Constants::Auth::VERIFY_PAGE_AUTHENTICATED }
        let(:expected_op_value) { '' }

        it_behaves_like 'an idme service interface with appropriate operation'
      end

      context 'and the operation param is verify_page_unauthenticated' do
        let(:operation_value) { SignIn::Constants::Auth::VERIFY_PAGE_UNAUTHENTICATED }
        let(:expected_op_value) { '' }

        it_behaves_like 'an idme service interface with appropriate operation'
      end
    end

    shared_context 'an idme service interface with appropriate operation' do
      let(:expected_redirect_uri) { IdentitySettings.idme.redirect_uri }

      context 'and acr param is not given' do
        let(:acr) { {} }
        let(:acr_value) { nil }
        let(:expected_error) { 'ACR is not valid' }

        it_behaves_like 'authorize_error_response'
      end

      context 'and acr param is given but not in client service_levels' do
        let(:acr_value) { 'loa1' }
        let(:service_levels) { ['loa3'] }
        let(:expected_error) { 'ACR is not valid' }

        it_behaves_like 'authorize_error_response'
      end

      context 'and acr param is given and in client service_levels but not valid for type' do
        let(:acr_value) { 'ial1' }
        let(:expected_error) { "Invalid ACR for #{type_value}" }

        it_behaves_like 'authorize_error_response'
      end

      context 'and acr param is given and in client service_levels and valid for type' do
        let(:acr_value) { 'loa1' }

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
          let(:code_challenge_method) { { code_challenge_method: 'some-code-challenge-method' } }

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

    context 'when type param is idme' do
      let(:type_value) { SignIn::Constants::Auth::IDME }
      let(:expected_type_value) { SignIn::Constants::Auth::IDME }

      it_behaves_like 'an idme authentication service interface'
    end
  end
end
