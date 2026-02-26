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

      # Other valid operations (authorize, interstitial_verify, interstitial_signup,
      # verify_cta_authenticated, verify_page_authenticated, verify_page_unauthenticated)
      # all produce identical behavior (no op= param). Their convert_operation output is
      # verified in spec/lib/sign_in/idme/service_spec.rb ('when operation is a valid
      # non-signup operation'). Here we just confirm they are accepted without error.
      context 'and operation param is a valid non-signup operation' do
        let(:acr_value) { 'loa1' }
        let(:code_challenge) { { code_challenge: Base64.urlsafe_encode64('some-safe-code-challenge') } }
        let(:code_challenge_method) { { code_challenge_method: 'S256' } }

        [
          SignIn::Constants::Auth::AUTHORIZE,
          SignIn::Constants::Auth::INTERSTITIAL_VERIFY,
          SignIn::Constants::Auth::INTERSTITIAL_SIGNUP,
          SignIn::Constants::Auth::VERIFY_CTA_AUTHENTICATED,
          SignIn::Constants::Auth::VERIFY_PAGE_AUTHENTICATED,
          SignIn::Constants::Auth::VERIFY_PAGE_UNAUTHENTICATED
        ].each do |op|
          context "with operation=#{op}" do
            let(:operation_value) { op }

            it 'returns ok status' do
              expect(subject).to have_http_status(:ok)
            end
          end
        end
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

    context 'when type param is dslogon' do
      let(:type_value) { SignIn::Constants::Auth::DSLOGON }
      let(:acr_value) { 'loa1' }
      let(:code_challenge) { { code_challenge: Base64.urlsafe_encode64('some-safe-code-challenge') } }
      let(:code_challenge_method) { { code_challenge_method: 'S256' } }

      it 'routes through the same Idme::Service as idme' do
        idme_service = instance_double(SignIn::Idme::Service)
        allow(SignIn::Idme::Service).to receive(:new).and_return(idme_service)
        allow(idme_service).to receive(:render_auth).and_return('<html></html>')

        subject

        expect(SignIn::Idme::Service).to have_received(:new).with(hash_including(type: SignIn::Constants::Auth::DSLOGON))
      end
    end
  end
end
