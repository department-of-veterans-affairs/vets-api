# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::SignInController, type: :controller do
  include_context 'token_setup'

  describe 'POST token' do
    context 'when grant_type is token-exchange' do
      let(:grant_type_value) { SignIn::Constants::Auth::TOKEN_EXCHANGE_GRANT }

      context 'and subject token param is not given' do
        let(:subject_token) { {} }
        let(:expected_error) { "Subject token can't be blank" }

        it_behaves_like 'token_error_response'
      end

      context 'and subject token type param is not given' do
        let(:subject_token_type) { {} }
        let(:expected_error) { "Subject token type can't be blank" }

        it_behaves_like 'token_error_response'
      end

      context 'and actor_token param is not given' do
        let(:actor_token) { {} }
        let(:expected_error) { "Actor token can't be blank" }

        it_behaves_like 'token_error_response'
      end

      context 'and client_id param is not given' do
        let(:client_id_param) { {} }
        let(:expected_error) { "Client can't be blank" }

        it_behaves_like 'token_error_response'
      end

      context 'and subject token is not a valid access token' do
        let(:subject_token_value) { 'some-subject-token' }
        let(:expected_error) { 'Access token JWT is malformed' }

        it_behaves_like 'token_error_response'
      end

      context 'and subject token is a valid access token' do
        let(:subject_token_value) { SignIn::AccessTokenJwtEncoder.new(access_token: current_access_token).perform }
        let(:current_access_token) do
          create(:access_token, session_handle: current_session.handle,
                                device_secret_hash: hashed_device_secret,
                                client_id:)
        end
        let!(:current_session) { create(:oauth_session, hashed_device_secret:, user_account:, user_verification:) }
        let(:hashed_device_secret) { Digest::SHA256.hexdigest(device_secret) }
        let(:user_account) { user_verification.user_account }
        let(:device_secret) { 'some-device-secret' }

        context 'and subject token type is arbitrary' do
          let(:subject_token_type_value) { 'some-subject-token' }
          let(:expected_error) { 'subject token type is invalid' }

          it_behaves_like 'token_error_response'
        end

        context 'and subject token type is access token URN' do
          let(:subject_token_type_value) { SignIn::Constants::Urn::ACCESS_TOKEN }

          context 'and actor token is arbitrary' do
            let(:actor_token_value) { 'some-actor-token' }
            let(:expected_error) { 'actor token is invalid' }

            it_behaves_like 'token_error_response'
          end

          context 'and actor token is a valid device_secret' do
            let(:actor_token_value) { device_secret }

            context 'and actor token type is invalid' do
              let(:actor_token_type_value) { 'some-actor-token-type' }
              let(:expected_error) { 'actor token type is invalid' }

              it_behaves_like 'token_error_response'
            end

            context 'and actor token type is device_secret URN' do
              let(:actor_token_type_value) { SignIn::Constants::Urn::DEVICE_SECRET }
              let(:new_client_config) do
                create(:client_config,
                       enforced_terms: new_client_enforced_terms,
                       shared_sessions: new_client_shared_sessions,
                       authentication: new_client_authentication,
                       anti_csrf: new_client_anti_csrf)
              end
              let(:new_client_enforced_terms) { nil }
              let(:new_client_anti_csrf) { true }
              let(:new_client_authentication) { SignIn::Constants::Auth::COOKIE }

              context 'and client id is not associated with a valid client config' do
                let(:client_id_value) { 'some-arbitrary-client-id' }
                let(:expected_error) { 'client configuration not found' }

                it_behaves_like 'token_error_response'
              end

              context 'and client id is associated with a valid client config' do
                let(:client_id_value) { new_client_config.client_id }

                context 'and client id is not associated with a shared sessions client' do
                  let(:new_client_shared_sessions) { false }
                  let(:expected_error) { 'tokens requested for client without shared sessions' }

                  it_behaves_like 'token_error_response'
                end

                context 'and client id is associated with a shared sessions client' do
                  let(:new_client_shared_sessions) { true }

                  context 'and current session is not associated with a device sso enabled client' do
                    let(:shared_sessions) { false }
                    let(:expected_error) { 'token exchange requested from invalid client' }

                    it_behaves_like 'token_error_response'
                  end

                  context 'and current session is associated with a device sso enabled client' do
                    let(:shared_sessions) { true }
                    let(:expected_generator_log) { '[SignInService] [SignIn::TokenResponseGenerator] token exchanged' }
                    let(:expected_log) { '[SignInService] [V0::SignInController] token' }

                    context 'and the retrieved UserVerification is locked' do
                      let(:user_verification) { create(:user_verification, locked: true) }
                      let(:expected_error) { 'Credential is locked' }

                      it_behaves_like 'token_error_response'
                    end

                    context 'and new client config is configured with enforced terms' do
                      let(:new_client_enforced_terms) { SignIn::Constants::Auth::VA_TERMS }

                      context 'and authenticating user has accepted current terms of use' do
                        let!(:terms_of_use_agreement) { create(:terms_of_use_agreement, user_account:) }

                        it 'returns ok status' do
                          expect(subject).to have_http_status(:ok)
                        end
                      end

                      context 'and authenticating user has not accepted current terms of use' do
                        let(:expected_error) { 'Terms of Use has not been accepted' }

                        it_behaves_like 'token_error_response'
                      end
                    end

                    it 'creates an OAuthSession' do
                      expect { subject }.to change(SignIn::OAuthSession, :count).by(1)
                    end

                    it 'returns ok status' do
                      expect(subject).to have_http_status(:ok)
                    end

                    context 'and requested tokens are for a session that is configured as api auth' do
                      let!(:user) { create(:user, :api_auth, uuid: user_uuid) }
                      let(:new_client_authentication) { SignIn::Constants::Auth::API }

                      context 'and authentication is for a session set up for device sso' do
                        let(:shared_sessions) { true }
                        let(:device_sso) { true }

                        it 'returns expected body without device_secret' do
                          expect(JSON.parse(subject.body)['data']).not_to have_key('device_secret')
                        end
                      end

                      it 'returns expected body with access token' do
                        expect(JSON.parse(subject.body)['data']).to have_key('access_token')
                      end

                      it 'returns expected body with refresh token' do
                        expect(JSON.parse(subject.body)['data']).to have_key('refresh_token')
                      end

                      it 'logs the successful token request' do
                        access_token = JWT.decode(JSON.parse(subject.body)['data']['access_token'], nil, false).first
                        logger_context = {
                          uuid: access_token['jti'],
                          user_uuid: access_token['sub'],
                          session_handle: access_token['session_handle'],
                          client_id: access_token['client_id'],
                          audience: access_token['aud'],
                          version: access_token['version'],
                          last_regeneration_time: access_token['last_regeneration_time'],
                          created_time: access_token['iat'],
                          expiration_time: access_token['exp']
                        }
                        expect(Rails.logger).to have_received(:info).with(expected_log, {})
                        expect(Rails.logger).to have_received(:info).with(expected_generator_log, logger_context)
                      end

                      it 'updates StatsD with a token request success' do
                        expect { subject }.to trigger_statsd_increment(statsd_token_success)
                      end
                    end

                    context 'and authentication is for a session that is configured as cookie auth' do
                      let(:new_client_authentication) { SignIn::Constants::Auth::COOKIE }
                      let(:access_token_cookie_name) { SignIn::Constants::Auth::ACCESS_TOKEN_COOKIE_NAME }
                      let(:refresh_token_cookie_name) { SignIn::Constants::Auth::REFRESH_TOKEN_COOKIE_NAME }

                      it 'returns empty hash for body' do
                        expect(JSON.parse(subject.body)).to eq({})
                      end

                      it 'sets access token cookie' do
                        expect(subject.cookies).to have_key(access_token_cookie_name)
                      end

                      it 'sets refresh token cookie' do
                        expect(subject.cookies).to have_key(refresh_token_cookie_name)
                      end

                      context 'and session is configured as anti csrf enabled' do
                        let(:new_client_anti_csrf) { true }
                        let(:anti_csrf_token_cookie_name) { SignIn::Constants::Auth::ANTI_CSRF_COOKIE_NAME }

                        it 'returns expected body with refresh token' do
                          expect(subject.cookies).to have_key(anti_csrf_token_cookie_name)
                        end
                      end

                      it 'logs the successful token request' do
                        access_token_cookie = subject.cookies[access_token_cookie_name]
                        access_token = JWT.decode(access_token_cookie, nil, false).first
                        logger_context = {
                          uuid: access_token['jti'],
                          user_uuid: access_token['sub'],
                          session_handle: access_token['session_handle'],
                          client_id: access_token['client_id'],
                          audience: access_token['aud'],
                          version: access_token['version'],
                          last_regeneration_time: access_token['last_regeneration_time'],
                          created_time: access_token['iat'],
                          expiration_time: access_token['exp']
                        }
                        expect(Rails.logger).to have_received(:info).with(expected_log, {})
                        expect(Rails.logger).to have_received(:info).with(expected_generator_log, logger_context)
                      end

                      it 'updates StatsD with a token request success' do
                        expect { subject }.to trigger_statsd_increment(statsd_token_success)
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
end
