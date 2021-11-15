# frozen_string_literal: true

require 'rails_helper'
require 'sentry_logging'

shared_examples 'a sentry logger' do
  subject { class_instance }

  let(:class_instance) { described_class.new }
  let(:exception) { StandardError.new }

  context 'with SENTRY_DSN set' do
    before { Settings.sentry.dsn = 'asdf' }

    after { Settings.sentry.dsn = nil }

    describe '#log_message_to_sentry' do
      it 'error logs to Rails logger' do
        expect(Rails.logger).to receive(:error).with(/blah/).with(/context/)
        subject.log_message_to_sentry('blah', :error, { extra: 'context' }, tags: 'tagging')
      end

      it 'logs to Sentry' do
        expect(Raven).to receive(:tags_context)
        expect(Raven).to receive(:extra_context)
        expect(Raven).to receive(:capture_message)
        subject.log_message_to_sentry('blah', :error, { extra: 'context' }, tags: 'tagging')
      end
    end

    describe '#log_exception_to_sentry' do
      it 'warn logs to Rails logger' do
        expect(Rails.logger).to receive(:error).with("#{exception.message}.")
        subject.log_exception_to_sentry(exception)
      end

      it 'logs to Sentry' do
        expect(Raven).to receive(:capture_exception).with(exception, level: 'error').once
        subject.log_exception_to_sentry(exception)
      end
    end
  end

  context 'without SENTRY_DSN set' do
    describe '#log_message_to_sentry' do
      it 'warn logs to Rails logger' do
        expect(Rails.logger).to receive(:warn).with(/blah/).with(/context/)
        subject.log_message_to_sentry('blah', :warn, { extra: 'context' }, tags: 'tagging')
      end

      it 'does not log to Sentry' do
        expect(Raven).to receive(:capture_exception).exactly(0).times
        subject.log_message_to_sentry('blah', :warn, { extra: 'context' }, tags: 'tagging')
      end
    end

    describe '#log_exception_to_sentry' do
      it 'error logs to Rails logger' do
        expect(Rails.logger).to receive(:error).with("#{exception.message}.")
        subject.log_exception_to_sentry(exception)
      end

      it 'does not log to Sentry' do
        expect(Raven).to receive(:capture_exception).exactly(0).times
        subject.log_exception_to_sentry(exception)
      end
    end
  end
end
