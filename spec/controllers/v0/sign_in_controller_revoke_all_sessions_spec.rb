# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::SignInController, type: :controller do
  include_context 'revoke_all_sessions_setup'

  describe 'GET revoke_all_sessions' do
    context 'when successfully authenticated' do
      it 'deletes all OAuthSession objects associated with current user user_account' do
        expect { subject }.to change(SignIn::OAuthSession, :count).from(oauth_session_count).to(0)
      end

      it 'returns ok status' do
        expect(subject).to have_http_status(expected_status)
      end

      it 'logs the revoke all sessions call' do
        expect(Rails.logger).to receive(:info).with(expected_log, expected_log_params)
        subject
      end

      it 'triggers statsd increment for successful call' do
        expect { subject }.to trigger_statsd_increment(statsd_success)
      end

      context 'and no session matches the access token session handle' do
        let(:expected_error) { SignIn::Errors::SessionNotFoundError }
        let(:expected_error_message) { 'Session not found' }

        before do
          oauth_session.destroy!
        end

        it_behaves_like 'revoke_all_sessions_error_response'
      end

      context 'and some arbitrary Sign in Error is raised' do
        let(:expected_error) { SignIn::Errors::StandardError }
        let(:expected_error_message) { expected_error.to_s }

        before do
          allow(SignIn::RevokeSessionsForUser).to receive(:new).and_raise(expected_error.new(message: expected_error))
        end

        it_behaves_like 'revoke_all_sessions_error_response'
      end
    end
  end
end
