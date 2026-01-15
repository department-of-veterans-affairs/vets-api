# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SemanticLogger do
  before do
    SemanticLogger.default_level = :info
  end

  # NOTE: never disabled now
  context 'when outputting errors and exceptions' do
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

    describe 'SafeSemanticLogEntry' do
      context 'when creating log entries directly' do
        it 'normalizes string exceptions in log entry initialization' do
          log_entry = SemanticLogger::Log.new('TestLogger', :error, 0)
          log_entry.instance_variable_set(:@exception, 'string exception')

          # Trigger initialize through SemanticLogger
          expect do
            Rails.logger.error('test', exception: 'direct string exception')
          end.not_to raise_error
        end

        it 'converts string exception to RuntimeError with backtrace' do
          captured_exceptions = []
          allow_any_instance_of(SemanticLogger::Appender::File).to receive(:log) do |_appender, log|
            captured_exceptions << log.exception if log.exception
          end

          Rails.logger.error('test', exception: 'string error in log entry')

          runtime_errors = captured_exceptions.select { |e| e.is_a?(RuntimeError) }
          expect(runtime_errors).not_to be_empty
          expect(runtime_errors.first.message).to eq('string error in log entry')
          expect(runtime_errors.first.backtrace).to be_present
        end

        it 'preserves proper exceptions without modification' do
          captured_exceptions = []
          allow_any_instance_of(SemanticLogger::Appender::File).to receive(:log) do |_appender, log|
            captured_exceptions << log.exception if log.exception
          end

          original_error = StandardError.new('original error')
          original_error.set_backtrace(%w[line1 line2])

          Rails.logger.error('test', exception: original_error)

          expect(captured_exceptions).to include(original_error)
          expect(captured_exceptions.first.backtrace).to eq(%w[line1 line2])
        end

        it 'does not raise errors when exception lacks backtrace method' do
          # Create an object that doesn't respond to backtrace
          fake_exception = Object.new
          allow(fake_exception).to receive(:to_s).and_return('fake exception')

          expect do
            Rails.logger.error('test', exception: fake_exception)
          end.not_to raise_error
        end
      end

      context 'integration with SafeSemanticLogging' do
        it 'works together to prevent logging failures' do
          log_failure_messages = []
          allow_any_instance_of(SemanticLogger::Appender::File).to receive(:error) do |_appender, message, _error|
            log_failure_messages << message
          end

          # Test both patches working together
          100.times do |i|
            Rails.logger.error("Error #{i}", exception: "String exception #{i}")
          end

          expect(log_failure_messages).to be_empty
        end

        it 'handles mixed exception types in rapid succession' do
          exceptions = [
            'string exception',
            StandardError.new('proper exception'),
            nil,
            ArgumentError.new('another proper one'),
            'another string'
          ]

          expect do
            exceptions.each_with_index do |ex, i|
              Rails.logger.error("Message #{i}", exception: ex)
            end
          end.not_to raise_error
        end
      end
    end
  end
end
