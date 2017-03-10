# frozen_string_literal: true
require 'rails_helper'
require 'sentry_logging'

RSpec.describe SentryLogging do
  # TODO: Implement!
  describe '.log_message_to_sentry' do
    it 'logs to Rails logger'
    context 'without SENTRY_DSN set' do
      it 'does not log to Sentry'
    end
    context 'with SENTRY_DSN set' do
      it 'logs to Sentry'
    end
  end

  describe '.log_exception_to_sentry' do
    it 'logs to Rails logger'
    context 'without SENTRY_DSN set' do
      it 'does not log to Sentry'
    end
    context 'with SENTRY_DSN set' do
      it 'logs to Sentry'
    end
  end
end
