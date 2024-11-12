# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SignIn::TokenExchanger, type: :model do
  subject(:token_exchanger) do
    described_class.new(subject_token:, subject_token_type:, actor_token:, actor_token_type:, client_id:)
  end

  let(:subject_token) { 'some-subject-token' }
  let(:subject_token_type) { 'some-subject-token-type' }
  let(:actor_token) { 'some-actor-token' }
  let(:actor_token_type) { 'some-actor-token-type' }
  let(:client_id) { 'some-client-id' }

  describe '#perform' do
    context 'when subject_token is blank' do
      let(:subject_token) { nil }
      let(:expected_error) { SignIn::Errors::InvalidTokenError }
      let(:expected_error_message) { 'subject token is invalid' }

      it 'raises invalid token error' do
        expect { token_exchanger.perform }.to raise_error(expected_error, expected_error_message)
      end
    end

    context 'when subject_token is an invalid access token' do
      let(:subject_token) { 'some-invalid-access-token' }
      let(:expected_error) { SignIn::Errors::AccessTokenMalformedJWTError }
      let(:expected_error_message) { 'Access token JWT is malformed' }

      it 'raises malformed token error' do
        expect { token_exchanger.perform }.to raise_error(expected_error, expected_error_message)
      end
    end

    context 'when subject_token is a valid access token' do
      let(:subject_token) { SignIn::AccessTokenJwtEncoder.new(access_token: current_access_token).perform }
      let!(:current_session) { create(:oauth_session, hashed_device_secret: current_session_device_secret) }
      let(:current_access_token) do
        create(:access_token, session_handle: current_session.handle,
                              device_secret_hash: current_access_token_device_secret,
                              client_id: current_client_config.client_id)
      end
      let(:current_session_device_secret) { 'some-current-session-device-secret' }
      let(:current_access_token_device_secret) { 'some-current-access-token-device-secret' }
      let(:current_client_config) do
        create(:client_config, authentication: :api, shared_sessions: current_shared_sessions, enforced_terms: nil)
      end
      let(:current_shared_sessions) { true }

      context 'and subject_token_type does not access token URN' do
        let(:subject_token_type) { 'some-subject-token-type' }
        let(:expected_error) { SignIn::Errors::InvalidTokenTypeError }
        let(:expected_error_message) { 'subject token type is invalid' }

        it 'raises invalid token type error' do
          expect { token_exchanger.perform }.to raise_error(expected_error, expected_error_message)
        end
      end

      context 'and subject_token_type equals access token URN' do
        let(:subject_token_type) { SignIn::Constants::Urn::ACCESS_TOKEN }
        let(:device_secret) { 'some-device-secret' }
        let(:actor_token) { device_secret }

        context 'and hashed actor_token does not equal hashed device secret in current session' do
          let(:current_session_device_secret) { 'some-invalid-current-session-device-secret' }
          let(:expected_error) { SignIn::Errors::InvalidTokenError }
          let(:expected_error_message) { 'actor token is invalid' }

          it 'raises invalid token error' do
            expect { token_exchanger.perform }.to raise_error(expected_error, expected_error_message)
          end
        end

        context 'and hashed actor_token equals hashed device secret in current session' do
          let(:current_session_device_secret) { Digest::SHA256.hexdigest(device_secret) }

          context 'and hashed actor_token does not equal hashed device secret in current access token' do
            let(:current_access_token_device_secret) { 'some-invalid-current-access-token-device-secret' }
            let(:expected_error) { SignIn::Errors::InvalidTokenError }
            let(:expected_error_message) { 'actor token is invalid' }

            it 'raises invalid token error' do
              expect { token_exchanger.perform }.to raise_error(expected_error, expected_error_message)
            end
          end

          context 'and hashed actor_token equals hashed device secret in current access token' do
            let(:current_access_token_device_secret) { Digest::SHA256.hexdigest(device_secret) }

            context 'and actor_token_type does not equal device secret urn' do
              let(:actor_token_type) { 'some-actor-token-type' }
              let(:expected_error) { SignIn::Errors::InvalidTokenTypeError }
              let(:expected_error_message) { 'actor token type is invalid' }

              it 'raises invalid token type error' do
                expect { token_exchanger.perform }.to raise_error(expected_error, expected_error_message)
              end
            end

            context 'and actor_token_type equals device secret urn' do
              let(:actor_token_type) { SignIn::Constants::Urn::DEVICE_SECRET }
              let(:new_client_config) do
                create(:client_config,
                       access_token_attributes: %i[first_name last_name email all_emails],
                       shared_sessions:,
                       enforced_terms: nil)
              end

              context 'and client_id does not map to a valid client config' do
                let(:client_id) { 'some-arbitrary-client-id' }
                let(:expected_error) { SignIn::Errors::InvalidClientConfigError }
                let(:expected_error_message) { 'client configuration not found' }

                it 'raises invalid client config error' do
                  expect { token_exchanger.perform }.to raise_error(expected_error, expected_error_message)
                end
              end

              context 'and client_id maps to a valid client config' do
                let(:client_id) { new_client_config.client_id }

                context 'and client_id does not equal a valid client config with shared sessions enabled' do
                  let(:shared_sessions) { false }
                  let(:expected_error) { SignIn::Errors::InvalidClientConfigError }
                  let(:expected_error_message) { 'tokens requested for client without shared sessions' }

                  it 'raises invalid client config error' do
                    expect { token_exchanger.perform }.to raise_error(expected_error, expected_error_message)
                  end
                end

                context 'and client_id does equal a valid client config with shared sessions enabled' do
                  let(:shared_sessions) { true }

                  context 'and current client is not device_sso enabled' do
                    let(:current_shared_sessions) { false }
                    let(:expected_error) { SignIn::Errors::InvalidSSORequestError }
                    let(:expected_error_message) { 'token exchange requested from invalid client' }

                    it 'raises invalid sso request error' do
                      expect { token_exchanger.perform }.to raise_error(expected_error, expected_error_message)
                    end
                  end

                  context 'and current client is device_sso enabled' do
                    let(:current_shared_sessions) { true }
                    let(:expected_user_account_id) { current_session.user_account_id }
                    let(:expected_user_verification_id) { current_session.user_verification_id }
                    let(:expected_credential_email) { current_session.credential_email }
                    let(:expected_session_hashed_device_secret) { current_session.hashed_device_secret }
                    let(:expected_hashed_refresh_token) do
                      Digest::SHA256.hexdigest(new_refresh_token.parent_refresh_token_hash)
                    end
                    let(:expected_last_regeneration_time) { Time.zone.now }

                    let(:expected_refresh_expiration) do
                      expected_last_regeneration_time + new_client_config.refresh_token_duration
                    end
                    let(:expected_session_handle) { Faker::Internet.uuid }
                    let(:expected_client_id) { new_client_config.client_id }
                    let(:expected_user_attributes) { current_session.user_attributes }
                    let(:expected_refresh_creation) { current_session.refresh_creation }
                    let(:expected_audience) { SignIn::ClientConfig.where(shared_sessions: true).pluck(:client_id) }
                    let(:expected_device_secret_hash) { nil }
                    let(:expected_user_uuid) { current_session.user_verification.backing_credential_identifier }

                    before do
                      Timecop.freeze(Time.zone.now.floor)
                      allow(SecureRandom).to receive(:uuid).and_return(expected_session_handle)
                    end

                    after { Timecop.return }

                    it 'creates a session with the expected attributes' do
                      new_session = token_exchanger.perform.session
                      expect(new_session.client_id).to eq(expected_client_id)
                      expect(new_session.user_account_id).to eq(expected_user_account_id)
                      expect(new_session.user_verification_id).to eq(expected_user_verification_id)
                      expect(new_session.credential_email).to eq(expected_credential_email)
                      expect(new_session.user_attributes).to eq(expected_user_attributes)
                      expect(new_session.hashed_device_secret).to eq(expected_session_hashed_device_secret)
                      expect(new_session.refresh_creation).to eq(expected_refresh_creation)
                      expect(new_session.handle).to eq(expected_session_handle)
                      expect(new_session.refresh_expiration).to eq(expected_refresh_expiration)
                    end

                    it 'returns an access token with expected attributes' do
                      new_access_token = token_exchanger.perform.access_token
                      expect(new_access_token.session_handle).to eq(expected_session_handle)
                      expect(new_access_token.audience).to eq(expected_audience)
                      expect(new_access_token.client_id).to eq(expected_client_id)
                      expect(new_access_token.last_regeneration_time).to eq(expected_last_regeneration_time)
                      expect(new_access_token.user_attributes).to eq(JSON.parse(expected_user_attributes))
                      expect(new_access_token.user_uuid).to eq(expected_user_uuid)
                      expect(new_access_token.device_secret_hash).to eq(expected_device_secret_hash)
                    end

                    it 'returns a refresh token with the expected attributes' do
                      new_refresh_token = token_exchanger.perform.refresh_token
                      expect(new_refresh_token.session_handle).to eq(expected_session_handle)
                      expect(new_refresh_token.user_uuid).to eq(expected_user_uuid)
                    end

                    it 'returns the expected client_config' do
                      token_exchanger_client_config = token_exchanger.perform.client_config

                      expect(token_exchanger_client_config).to eq(new_client_config)
                    end
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end
