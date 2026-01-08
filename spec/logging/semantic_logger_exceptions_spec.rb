# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SemanticLogger do
  before do
    SemanticLogger.default_level = :info
    allow(Flipper).to receive(:enabled?).with(:safe_semantic_logging).and_return(feature_flag_enabled)
  end

  context 'when FeatureFlag::SafeSemanticLogging is disabled' do
    let(:feature_flag_enabled) { false }

    it 'emits an appender failure' do
      log_failure_messages = []
      allow_any_instance_of(SemanticLogger::Appender::File).to receive(:error) do |_appender, message, _error|
        log_failure_messages << message
      end

      Rails.logger.error('oops', exception: 'not an exception')

      expect(log_failure_messages).not_to be_empty
      expect(log_failure_messages.any? { |msg| msg.include?('Failed to log to appender') }).to be true
    end
  end

  context 'when FeatureFlag::SafeSemanticLogging is enabled' do
    let(:feature_flag_enabled) { true }

    context 'and exception is a String' do
      it 'does not emit an appender failure' do
        log_failure_messages = []
        allow_any_instance_of(SemanticLogger::Appender::File).to receive(:error) do |_appender, message, _error|
          log_failure_messages << message
        end

        Rails.logger.error('oops', exception: 'not an exception')

        expect(log_failure_messages).to be_empty
      end

      it 'still sends normal log messages' do
        normal_log_messages = []
        normal_log_exceptions = []
        allow_any_instance_of(SemanticLogger::Appender::File).to receive(:log) do |_appender, log|
          normal_log_messages << log.instance_variable_get(:@message)
          normal_log_exceptions << log.exception
        end

        Rails.logger.error('oops', exception: 'not an exception')

        expect(normal_log_messages.any? { |msg| msg.include?('oops') }).to be true
        expect(normal_log_exceptions.any? do |e|
          e.is_a?(RuntimeError) && e.message == 'not an exception'
        end).to be true
      end
    end

    context 'and exception is nil' do
      it 'does not emit an appender failure' do
        log_failure_messages = []
        allow_any_instance_of(SemanticLogger::Appender::File).to receive(:error) do |_appender, message, _error|
          log_failure_messages << message
        end

        Rails.logger.error('oops', exception: nil)

        expect(log_failure_messages).to be_empty
      end

      it 'still logs normally when exception key is nil' do
        normal_log_messages = []
        normal_log_exceptions = []
        allow_any_instance_of(SemanticLogger::Appender::File).to receive(:log) do |_appender, log|
          normal_log_messages << log.instance_variable_get(:@message)
          normal_log_exceptions << log.exception
        end

        Rails.logger.error('oops', exception: nil)

        expect(normal_log_messages.any? { |msg| msg.include?('oops') }).to be true

        # We no longer create a placeholder exception when nil is passed
        # expect(normal_log_exceptions.any? do |e|
        #   e.is_a?(RuntimeError) && e.message == 'No exception provided'
        # end).to be true
      end
    end

    context 'and exception is an Exception' do
      it 'does not emit an appender failure' do
        log_failure_messages = []
        allow_any_instance_of(SemanticLogger::Appender::File).to receive(:error) do |_appender, message, _error|
          log_failure_messages << message
        end

        ex = RuntimeError.new('this is an error')
        Rails.logger.error('oops', exception: ex)

        expect(log_failure_messages).to be_empty
      end

      it 'logs normally' do
        normal_log_messages = []
        normal_log_exceptions = []
        allow_any_instance_of(SemanticLogger::Appender::File).to receive(:log) do |_appender, log|
          normal_log_messages << log.instance_variable_get(:@message)
          normal_log_exceptions << log.exception
        end

        ex = RuntimeError.new('this is an error')
        Rails.logger.error('oops', exception: ex)

        expect(normal_log_messages.any? { |msg| msg.include?('oops') }).to be true
        expect(normal_log_exceptions.any? do |e|
          e.is_a?(RuntimeError) && e.message == 'this is an error'
        end).to be true
      end
    end
  end
end
