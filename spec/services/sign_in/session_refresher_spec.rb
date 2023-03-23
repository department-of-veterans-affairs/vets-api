# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SignIn::SessionRefresher do
  let(:session_refresher) do
    SignIn::SessionRefresher.new(refresh_token:, anti_csrf_token: input_anti_csrf_token)
  end

  describe '#perform' do
    subject { session_refresher.perform }

    context 'given a refresh token and anti csrf token' do
      let(:refresh_token) do
        create(:refresh_token,
               anti_csrf_token:,
               session_handle:,
               parent_refresh_token_hash:,
               user_uuid:)
      end
      let(:parent_refresh_token) { create(:refresh_token, user_uuid:, session_handle:) }
      let(:parent_refresh_token_hash) { Digest::SHA256.hexdigest(parent_refresh_token.to_json) }
      let(:session_hashed_refresh_token) { Digest::SHA256.hexdigest(parent_refresh_token_hash) }
      let(:anti_csrf_token) { 'some-anti-csrf-token' }
      let(:input_anti_csrf_token) { anti_csrf_token }
      let(:session_handle) { SecureRandom.uuid }
      let(:user_uuid) { user_verification.credential_identifier }
      let(:user_verification) { create(:user_verification, user_account:) }
      let(:user_account) { create(:user_account) }
      let!(:session) do
        create(:oauth_session,
               refresh_expiration: session_expiration,
               hashed_refresh_token: session_hashed_refresh_token,
               handle: session_handle,
               user_account:,
               client_id:)
      end
      let(:session_expiration) { Time.zone.now + 5.minutes }
      let(:client_id) { client_config.client_id }
      let(:client_config) do
        create(:client_config, anti_csrf:, refresh_token_duration:)
      end
      let(:anti_csrf) { false }
      let(:refresh_token_duration) { SignIn::Constants::RefreshToken::VALIDITY_LENGTH_SHORT_MINUTES }

      before { Timecop.freeze(Time.zone.now.floor) }

      after { Timecop.return }

      context 'when session handle in refresh token matches an existing oauth session' do
        context 'and session is not expired' do
          context 'and client in session is configured to check for anti csrf' do
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
            let(:expected_error_message) { "Couldn't find SignIn::ClientConfig" }
            let(:arbitrary_client_id) { 'some-client-id' }

            before do
              allow_any_instance_of(SignIn::OAuthSession).to receive(:client_id).and_return(arbitrary_client_id)
            end

            it 'raises a record not found Error' do
              expect { subject }.to raise_error(expected_error, expected_error_message)
            end
          end

          context 'and token hash in session matches either input refresh token or its stored parent' do
            context 'and token hash in session specifically matches stored parent of input refresh token' do
              let(:double_hashed_refresh_token) do
                Digest::SHA256.hexdigest(Digest::SHA256.hexdigest(refresh_token.to_json))
              end

              context 'and client is configured with a short refresh token expiration time' do
                let(:refresh_token_duration) { SignIn::Constants::RefreshToken::VALIDITY_LENGTH_SHORT_MINUTES }
                let(:updated_session_expiration) { Time.zone.now + refresh_token_duration }

                it 'updates the session with a new expiration time' do
                  expect do
                    subject
                    session.reload
                  end.to change(session, :refresh_expiration).from(session_expiration)
                                                             .to(updated_session_expiration)
                end
              end

              context 'and client is configured with a long refresh token expiration time' do
                let(:refresh_token_duration) { SignIn::Constants::RefreshToken::VALIDITY_LENGTH_LONG_DAYS }
                let(:updated_session_expiration) { Time.zone.now + refresh_token_duration }

                it 'updates the session with a new expiration time' do
                  expect do
                    subject
                    session.reload
                  end.to change(session, :refresh_expiration).from(session_expiration)
                                                             .to(updated_session_expiration)
                end
              end

              it 'updates the session hashed_refresh_token with the input refresh token' do
                expect do
                  subject
                  session.reload
                end.to change(session, :hashed_refresh_token).from(session_hashed_refresh_token)
                                                             .to(double_hashed_refresh_token)
              end
            end

            context 'new token creation' do
              context 'expected anti_csrf_token' do
                let(:expected_anti_csrf_token) { 'some-anti-csrf-token' }

                before do
                  allow(SecureRandom).to receive(:hex).and_return(expected_anti_csrf_token)
                end

                it 'returns a Session Container with expected anti_csrf_token' do
                  expect(subject.anti_csrf_token).to be(expected_anti_csrf_token)
                end
              end

              context 'expected session' do
                it 'returns existing OAuth Session' do
                  expect(subject.session.id).to be session.id
                end
              end

              context 'expected refresh token' do
                let(:expected_anti_csrf_token) { 'some-anti-csrf-token' }
                let(:expected_refresh_token_hash) { Digest::SHA256.hexdigest(refresh_token.to_json) }

                before do
                  allow(SecureRandom).to receive(:hex).and_return(expected_anti_csrf_token)
                end

                it 'returns a new refresh token with expected attributes' do
                  container = subject
                  expect(container.refresh_token.session_handle).to eq(session.handle)
                  expect(container.refresh_token.user_uuid).to eq(user_uuid)
                  expect(container.refresh_token.anti_csrf_token).to eq(expected_anti_csrf_token)
                  expect(container.refresh_token.parent_refresh_token_hash).to eq(expected_refresh_token_hash)
                end
              end

              context 'expected access token' do
                let(:expected_anti_csrf_token) { 'some-anti-csrf-token' }
                let(:expected_parent_refresh_token_hash) { Digest::SHA256.hexdigest(refresh_token.to_json) }
                let(:expected_last_regeneration_time) { Time.zone.now }

                before do
                  allow(SecureRandom).to receive(:hex).and_return(expected_anti_csrf_token)
                end

                it 'returns a new access token with expected attributes' do
                  container = subject
                  expected_refresh_token_hash = Digest::SHA256.hexdigest(container.refresh_token.to_json)
                  expect(container.access_token.session_handle).to eq(session.handle)
                  expect(container.access_token.user_uuid).to eq(user_uuid)
                  expect(container.access_token.anti_csrf_token).to eq(expected_anti_csrf_token)
                  expect(container.access_token.parent_refresh_token_hash).to eq(expected_parent_refresh_token_hash)
                  expect(container.access_token.refresh_token_hash).to eq(expected_refresh_token_hash)
                  expect(container.access_token.last_regeneration_time).to eq(expected_last_regeneration_time)
                end
              end
            end
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
          let(:session_expiration) { Time.zone.now - 30.minutes }
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
  end
end
