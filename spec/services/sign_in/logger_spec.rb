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
end
