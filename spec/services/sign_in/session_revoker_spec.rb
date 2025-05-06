# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SignIn::SessionRevoker do
  let(:session_revoker) do
    SignIn::SessionRevoker.new(refresh_token:,
                               anti_csrf_token: input_anti_csrf_token,
                               access_token:,
                               device_secret:)
  end

  describe '#perform' do
    subject { session_revoker.perform }

    shared_examples 'device_secret session revoker' do
      context 'and a device_secret is provided' do
        let(:device_secret) { 'some-device-secret' }

        context 'and other sessions exist with the same device_secret' do
          let!(:connected_session) do
            create(:oauth_session, hashed_device_secret: Digest::SHA256.hexdigest(device_secret))
          end

          it 'destroys all other sessions with the same device_secret' do
            expect(SignIn::OAuthSession.all).to contain_exactly(session, connected_session)
            session_revoker.perform
            expect(SignIn::OAuthSession.all).to eq([])
          end
        end

        context 'and no other sessions exist with the same device_secret' do
          it 'does not attempt to destroy any other sessions' do
            expect_any_instance_of(SignIn::OAuthSession).to receive(:destroy!).once.and_call_original
            session_revoker.perform
          end
        end
      end

      context 'and a device_secret is not provided' do
        let(:device_secret) { nil }

        it 'does not attempt to destroy any other sessions' do
          expect_any_instance_of(SignIn::OAuthSession).to receive(:destroy!).once.and_call_original
          session_revoker.perform
        end
      end
    end

    context 'given a refresh token' do
      let(:refresh_token) do
        create(:refresh_token,
               anti_csrf_token:,
               session_handle:,
               parent_refresh_token_hash:,
               user_uuid:)
      end
      let(:access_token) { nil }
      let(:device_secret) { nil }
      let(:parent_refresh_token) { create(:refresh_token, user_uuid:, session_handle:) }
      let(:parent_refresh_token_hash) { Digest::SHA256.hexdigest(parent_refresh_token.to_json) }
      let(:session_hashed_refresh_token) { Digest::SHA256.hexdigest(parent_refresh_token_hash) }
      let(:anti_csrf_token) { 'some-anti-csrf-token' }
      let(:input_anti_csrf_token) { anti_csrf_token }
      let(:session_handle) { SecureRandom.uuid }
      let(:user_uuid) { user_account.id }
      let(:user_account) { create(:user_account) }
      let!(:session) do
        create(:oauth_session,
               refresh_expiration: session_expiration,
               hashed_refresh_token: session_hashed_refresh_token,
               handle: session_handle,
               user_account:,
               client_id:,
               hashed_device_secret: device_secret)
      end
      let(:client_id) { client_config.client_id }
      let(:client_config) { create(:client_config, anti_csrf:) }
      let(:anti_csrf) { false }
      let(:session_expiration) { 5.minutes.from_now }

      before do
        Timecop.freeze(Time.zone.now.floor)
      end

      after { Timecop.return }

      context 'when session handle in refresh token matches an existing oauth session' do
        context 'and session is not expired' do
          context 'and client is configured to check for anti csrf' do
            let(:anti_csrf) { true }

            context 'and anti csrf token does not match value in refresh token' do
              let(:input_anti_csrf_token) { 'some-arbitrary-csrf-token-value' }
              let(:expected_error) { SignIn::Errors::AntiCSRFMismatchError }
              let(:expected_error_message) { 'Anti CSRF token is not valid' }

              it 'raises an AntiCSRFMismatch Error' do
                expect { subject }.to raise_error(expected_error, expected_error_message)
              end
            end
          end

          context 'and client in session does not match an existing client configuration' do
            let(:expected_error) { ActiveRecord::RecordNotFound }
            let(:expected_error_message) { /Couldn't find SignIn::ClientConfig/ }
            let(:arbitrary_client_id) { 'some-client-id' }

            before do
              allow_any_instance_of(SignIn::OAuthSession).to receive(:client_id).and_return(arbitrary_client_id)
            end

            it 'raises a record not found Error' do
              expect { subject }.to raise_error(expected_error, expected_error_message)
            end
          end

          context 'and token hash in session specifically matches stored parent of input refresh token' do
            let(:double_hashed_refresh_token) do
              Digest::SHA256.hexdigest(Digest::SHA256.hexdigest(refresh_token.to_json))
            end

            it 'destroys the session' do
              session_revoker.perform
              expect { session.reload }.to raise_error(ActiveRecord::RecordNotFound)
            end

            it_behaves_like 'device_secret session revoker'
          end

          context 'and token hash in session does not match input refresh token or its stored parent' do
            let(:session_hashed_refresh_token) { 'some-arbitrary-refresh-token-hash' }
            let(:expected_error) { SignIn::Errors::TokenTheftDetectedError }
            let(:expected_error_message) { 'Token theft detected' }

            it 'raises a token theft detected error' do
              expect { subject }.to raise_error(expected_error, expected_error_message)
            end

            it 'destroys the existing session' do
              expect { try(subject) }.to raise_error(StandardError)
                .and change(SignIn::OAuthSession, :count).from(1).to(0)
            end
          end
        end

        context 'and session is expired' do
          let(:session_expiration) { 30.minutes.ago }
          let(:expected_error) { SignIn::Errors::SessionNotAuthorizedError }
          let(:expected_error_message) { 'No valid Session found' }

          it 'raises a session not authorized error' do
            expect { subject }.to raise_error(expected_error, expected_error_message)
          end
        end
      end

      context 'when session handle in refresh token does not match an existing oauth session' do
        let(:refresh_token_session_handle) { SecureRandom.uuid }
        let(:expected_error) { SignIn::Errors::SessionNotAuthorizedError }
        let(:expected_error_message) { 'No valid Session found' }
        let(:refresh_token) do
          create(:refresh_token, session_handle: refresh_token_session_handle, anti_csrf_token:)
        end

        it 'raises a session not authorized error' do
          expect { subject }.to raise_error(expected_error, expected_error_message)
        end
      end
    end

    context 'given an access token' do
      let(:access_token) do
        create(:refresh_token,
               anti_csrf_token:,
               session_handle:,
               user_uuid:)
      end
      let(:device_secret) { nil }
      let(:refresh_token) { nil }
      let(:anti_csrf_token) { 'some-anti-csrf-token' }
      let(:input_anti_csrf_token) { anti_csrf_token }
      let(:session_handle) { SecureRandom.uuid }
      let(:user_uuid) { user_account.id }
      let(:user_account) { create(:user_account) }
      let!(:session) do
        create(:oauth_session,
               refresh_expiration: session_expiration,
               handle: session_handle,
               user_account:,
               client_id:,
               hashed_device_secret: device_secret)
      end
      let(:client_id) { client_config.client_id }
      let(:client_config) { create(:client_config, anti_csrf:) }
      let(:anti_csrf) { false }
      let(:session_expiration) { 5.minutes.from_now }

      before do
        Timecop.freeze(Time.zone.now.floor)
      end

      after { Timecop.return }

      context 'when session handle in access token matches an existing oauth session' do
        context 'and session is not expired' do
          context 'and client is configured to check for anti csrf' do
            let(:anti_csrf) { true }

            context 'and anti csrf token does not match value in refresh token' do
              let(:input_anti_csrf_token) { 'some-arbitrary-csrf-token-value' }
              let(:expected_error) { SignIn::Errors::AntiCSRFMismatchError }
              let(:expected_error_message) { 'Anti CSRF token is not valid' }

              it 'raises an AntiCSRFMismatch Error' do
                expect { subject }.to raise_error(expected_error, expected_error_message)
              end
            end
          end

          context 'and client in session does not match an existing client configuration' do
            let(:expected_error) { ActiveRecord::RecordNotFound }
            let(:expected_error_message) { /Couldn't find SignIn::ClientConfig/ }
            let(:arbitrary_client_id) { 'some-client-id' }

            before do
              allow_any_instance_of(SignIn::OAuthSession).to receive(:client_id).and_return(arbitrary_client_id)
            end

            it 'raises a record not found Error' do
              expect { subject }.to raise_error(expected_error, expected_error_message)
            end
          end

          it 'destroys the session' do
            session_revoker.perform
            expect { session.reload }.to raise_error(ActiveRecord::RecordNotFound)
          end

          it_behaves_like 'device_secret session revoker'
        end

        context 'and session is expired' do
          let(:session_expiration) { 30.minutes.ago }
          let(:expected_error) { SignIn::Errors::SessionNotAuthorizedError }
          let(:expected_error_message) { 'No valid Session found' }

          it 'raises a session not authorized error' do
            expect { subject }.to raise_error(expected_error, expected_error_message)
          end
        end
      end

      context 'when session handle in access token does not match an existing oauth session' do
        let(:access_token_session_handle) { SecureRandom.uuid }
        let(:expected_error) { SignIn::Errors::SessionNotAuthorizedError }
        let(:expected_error_message) { 'No valid Session found' }
        let(:access_token) do
          create(:access_token, session_handle: access_token_session_handle, anti_csrf_token:)
        end

        it 'raises a session not authorized error' do
          expect { subject }.to raise_error(expected_error, expected_error_message)
        end
      end
    end
  end
end
