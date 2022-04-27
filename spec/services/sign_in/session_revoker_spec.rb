# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SignIn::SessionRevoker do
  let(:session_revoker) do
    SignIn::SessionRevoker.new(refresh_token: refresh_token,
                               anti_csrf_token: input_anti_csrf_token,
                               enable_anti_csrf: enable_anti_csrf)
  end

  describe '#perform' do
    subject { session_revoker.perform }

    context 'given a refresh token' do
      let(:refresh_token) do
        create(:refresh_token,
               anti_csrf_token: anti_csrf_token,
               session_handle: session_handle,
               parent_refresh_token_hash: parent_refresh_token_hash,
               user_uuid: user_uuid)
      end
      let(:parent_refresh_token) { create(:refresh_token, user_uuid: user_uuid, session_handle: session_handle) }
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
               user_account: user_account)
      end
      let(:session_expiration) { Time.zone.now + 5.minutes }
      let(:enable_anti_csrf) { true }

      before { Timecop.freeze(Time.zone.now.floor) }

      after { Timecop.return }

      context 'when enable_anti_csrf is true' do
        let(:enable_anti_csft) { true }

        context 'and anti csrf token does not match value in refresh token' do
          let(:input_anti_csrf_token) { 'some-arbitrary-csrf-token-value' }
          let(:expected_error) { SignIn::Errors::AntiCSRFMismatchError }

          it 'raises an AntiCSRFMismatch Error' do
            expect { subject }.to raise_error(expected_error)
          end
        end
      end

      context 'when session handle in refresh token matches an existing oauth session' do
        context 'when session is not expired' do
          context 'when token hash in session specifically matches stored parent of input refresh token' do
            let(:double_hashed_refresh_token) do
              Digest::SHA256.hexdigest(Digest::SHA256.hexdigest(refresh_token.to_json))
            end

            it 'destroys the session' do
              session_revoker.perform
              expect { session.reload }.to raise_error(ActiveRecord::RecordNotFound)
            end
          end

          context 'when token hash in session does not match input refresh token or its stored parent' do
            let(:session_hashed_refresh_token) { 'some-arbitrary-refresh-token-hash' }
            let(:expected_error) { SignIn::Errors::TokenTheftDetectedError }

            it 'raises a token theft detected error' do
              expect { subject }.to raise_error(expected_error)
            end
          end
        end

        context 'when session is expired' do
          let(:session_expiration) { Time.zone.now - 30.minutes }
          let(:expected_error) { SignIn::Errors::SessionNotAuthorizedError }

          it 'raises a session not authorized error' do
            expect { subject }.to raise_error(expected_error)
          end
        end
      end

      context 'when session handle in refresh token does not match an existing oauth session' do
        let(:refresh_token_session_handle) { SecureRandom.uuid }
        let(:expected_error) { SignIn::Errors::SessionNotAuthorizedError }
        let(:refresh_token) do
          create(:refresh_token, session_handle: refresh_token_session_handle, anti_csrf_token: anti_csrf_token)
        end

        it 'raises a session not authorized error' do
          expect { subject }.to raise_error(expected_error)
        end
      end
    end
  end
end
