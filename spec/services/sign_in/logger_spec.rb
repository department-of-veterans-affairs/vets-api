# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SignIn::Logger do
  let(:logger) { SignIn::Logger.new(prefix: prefix) }
  let(:prefix) { 'some-logger-prefix' }
  let(:user_account) { create(:user_account) }
  let(:expected_logger_message) { "[SignInService] [#{prefix}] #{message}" }
  let(:message) { 'some-message' }
  let(:attribute) { 'some-attribute' }

  before do
    allow(Rails.logger).to receive(:info)
  end

  describe '#info' do
    it 'create a Rails info log with expected values' do
      expect(Rails.logger).to receive(:info).with(expected_logger_message, { attribute: attribute })
      logger.info(message, { attribute: attribute })
    end
  end

  describe '#refresh_token_log' do
    let(:refresh_token) { create(:refresh_token, user_uuid: user_account.id) }
    let(:code) { 'some-code' }
    let(:attributes) do
      {
        code: code,
        token_type: 'Refresh',
        user_id: user_account.id,
        session_id: refresh_token.session_handle
      }
    end

    it 'logs the refresh token' do
      expect(Rails.logger).to receive(:info).with(expected_logger_message, attributes)
      logger.refresh_token_log(message, refresh_token, { code: code })
    end
  end

  describe '#access_token_log' do
    let(:access_token) { create(:access_token, user_uuid: user_account.id) }
    let(:attributes) do
      {
        user_id: user_account.id,
        token_type: 'Access',
        access_token_id: access_token.uuid,
        session_id: access_token.session_handle
      }
    end

    it 'logs the access token' do
      expect(Rails.logger).to receive(:info).with(expected_logger_message, attributes)
      logger.access_token_log(message, access_token)
    end
  end
end
