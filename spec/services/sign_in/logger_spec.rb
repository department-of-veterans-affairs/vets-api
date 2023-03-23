# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SignIn::Logger do
  let(:logger) { SignIn::Logger.new(prefix:) }
  let(:prefix) { 'some-logger-prefix' }
  let(:user_account) { create(:user_account) }
  let(:expected_logger_message) { "[SignInService] [#{prefix}] #{message}" }
  let(:message) { 'some-message' }
  let(:attribute) { 'some-attribute' }

  before do
    allow(Rails.logger).to receive(:info)
  end

  describe '#info' do
    subject { logger.info(message, attributes) }

    let(:attributes) { { attribute: } }

    it 'create a Rails info log with expected values' do
      expect(Rails.logger).to receive(:info).with(expected_logger_message, attributes)
      subject
    end
  end

  describe '#token_log' do
    subject { logger.token_log(message, token) }

    context 'when invoked with an access token' do
      let(:token) { create(:access_token, user_uuid: user_account.id) }
      let(:attributes) do
        {
          user_uuid: user_account.id,
          session_id: token.session_handle,
          token_uuid: token.uuid
        }
      end

      it 'logs the token and session informatino' do
        expect(Rails.logger).to receive(:info).with(expected_logger_message, attributes)
        subject
      end
    end

    context 'when invoked with a refresh token' do
      let(:token) { create(:refresh_token, user_uuid: user_account.id) }
      let(:attributes) do
        {
          user_uuid: user_account.id,
          session_id: token.session_handle,
          token_uuid: token.uuid
        }
      end

      it 'logs the token and session informatino' do
        expect(Rails.logger).to receive(:info).with(expected_logger_message, attributes)
        subject
      end
    end
  end
end
