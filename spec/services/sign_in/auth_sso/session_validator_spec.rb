# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SignIn::AuthSSO::SessionValidator do
  subject(:validator) { described_class.new(access_token:, client_id:) }

  let(:client_id) { 'sso_client_id' }
  let(:credential_service_providers) { %w[idme logingov] }
  let(:service_levels) { %w[loa3 ial2] }
  let(:shared_sessions) { true }

  let!(:client_config) do
    create(
      :client_config,
      shared_sessions:,
      json_api_compatibility: false,
      client_id:,
      credential_service_providers:,
      service_levels:
    )
  end

  let!(:user_account) { create(:user_account) }
  let!(:user_verification) { create(:user_verification, user_account:) }

  let!(:session_client_config) do
    create(
      :client_config,
      shared_sessions:,
      authentication: SignIn::Constants::Auth::COOKIE
    )
  end

  let!(:session) do
    create(
      :oauth_session,
      client_id: session_client_config.client_id,
      user_verification:,
      user_account:
    )
  end

  let(:access_token) do
    create(
      :access_token,
      session_handle: session.handle,
      client_id:,
      user_uuid: user_account.id
    )
  end

  describe '#perform' do
    context 'when validations fail' do
      context 'when the access token is nil' do
        let(:access_token) { nil }

        it 'raises an AccessTokenUnauthenticatedError' do
          expect { validator.perform }
            .to raise_error(
              SignIn::Errors::AccessTokenUnauthenticatedError,
              'Access token is not authenticated'
            )
        end
      end

      context 'when the session is not found' do
        before do
          allow(SignIn::OAuthSession)
            .to receive(:find_by)
            .with(handle: access_token.session_handle)
            .and_return(nil)
        end

        it 'raises a SessionNotAuthorizedError' do
          expect { validator.perform }
            .to raise_error(
              SignIn::Errors::SessionNotAuthorizedError,
              'Session not authorized'
            )
        end
      end

      context 'when client configs are invalid' do
        context 'when client configs are not SSO enabled' do
          let(:shared_sessions) { false }

          it 'raises an InvalidClientConfigError' do
            expect { validator.perform }
              .to raise_error(
                SignIn::Errors::InvalidClientConfigError,
                'SSO requested for client without shared sessions'
              )
          end
        end
      end

      context 'when the credential service provider is invalid' do
        let(:credential_service_providers) { %w[mhv] }

        it 'raises an InvalidCredentialServiceProviderError' do
          expect { validator.perform }
            .to raise_error(
              SignIn::Errors::InvalidCredentialLevelError,
              'Invalid credential service provider'
            )
        end
      end

      context 'when the service level is invalid' do
        let(:service_levels) { ['loa1'] }

        it 'raises an InvalidServiceLevelError' do
          expect { validator.perform }
            .to raise_error(
              SignIn::Errors::InvalidCredentialLevelError,
              'Invalid service level'
            )
        end
      end
    end

    context 'when validations pass' do
      let(:expected_attributes) do
        {
          idme_uuid: user_verification.idme_uuid,
          logingov_uuid: user_verification.logingov_uuid,
          credential_email: session.credential_email,
          edipi: session.user_attributes_hash[:edipi],
          mhv_credential_uuid: user_verification.mhv_uuid,
          first_name: session.user_attributes_hash[:first_name],
          last_name: session.user_attributes_hash[:last_name],
          acr: SignIn::Constants::Auth::LOA3,
          type: user_verification.credential_type,
          icn: user_account.icn,
          session_id: session.id
        }
      end

      it 'returns the auth SSO user attributes' do
        expect(validator.perform).to eq(expected_attributes)
      end
    end
  end
end
