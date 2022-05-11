# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SignIn::Logger do
  let(:logger) { SignIn::Logger.new }
  let(:user_account) { create(:user_account) }
  let(:refresh_token) { create(:refresh_token, user_uuid: user_account.id) }

  before do
    Timecop.freeze(Time.zone.now.floor)
    allow(Rails.logger).to receive(:info)
  end

  after { Timecop.return }

  describe '#info_log' do
    let(:message) { 'Sign in Service Test Message' }
    let(:attribute) { 'asdf1234' }

    it 'create a Rails info log' do
      expect(Rails.logger).to receive(:info)
        .with(message, { attribute: attribute, timestamp: Time.zone.now.to_s })
      logger.info_log(message, { attribute: attribute })
    end
  end

  describe '#refresh_token_log' do
    let(:message) { 'Sign in Service Token Response' }
    let(:code) { SecureRandom.hex }

    it 'logs the refresh token' do
      expect(Rails.logger).to receive(:info)
        .with(message,
              { code: code, token_type: 'Refresh', user_id: user_account.id,
                session_id: refresh_token.session_handle, timestamp: Time.zone.now.to_s })
      logger.refresh_token_log(message, refresh_token, { code: code })
    end
  end

  describe '#access_token_log' do
    let(:access_token) { create(:access_token, user_uuid: user_account.id) }
    let(:message) { 'Sign in Service Introspect' }

    it 'logs the access token' do
      expect(Rails.logger).to receive(:info)
        .with(message,
              { token_type: 'Access', user_id: user_account.id, access_token_id: access_token.uuid,
                session_id: access_token.session_handle, timestamp: Time.zone.now.to_s })
      logger.access_token_log(message, access_token)
    end
  end
end
