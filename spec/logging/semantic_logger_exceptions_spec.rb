# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SemanticLogger do
  before do
    SemanticLogger.default_level = :info
  end

  context 'when exception is a String' do
    it 'does not emit an appender failure' do
      log_failure_messages = []
      allow_any_instance_of(SemanticLogger::Appender::File).to receive(:error) do |_appender, message, _error|
        log_failure_messages << message
      end

      normal_log_messages = []
      normal_log_exceptions = []
      allow_any_instance_of(SemanticLogger::Appender::File).to receive(:log) do |_appender, log|
        normal_log_messages << log.instance_variable_get(:@message)
        normal_log_exceptions << log.exception
      end

      Rails.logger.error('oops', exception: 'not an exception')

      expect(log_failure_messages).to be_empty

      expect(normal_log_messages.any? { |msg| msg.include?('oops') }).to be true
      expect(normal_log_exceptions.any? do |e|
        e.is_a?(RuntimeError) && e.message == 'not an exception'
      end).to be true

      # In particular we could test for absence of these specific failure messages but 'they are empty' is equivalent here
      # messages.each do |msg|
      #   expect(msg).not_to include("NoMethodError: undefined method `message' for an instance of String")
      #   expect(msg).not_to include('Failed to log to appender')
      # end
    end
  end

  context 'when exception is nil' do
    it 'logs normally' do
      log_failure_messages = []
      allow_any_instance_of(SemanticLogger::Appender::File).to receive(:error) do |_appender, message, _error|
        log_failure_messages << message
      end

      normal_log_messages = []
      normal_log_exceptions = []
      allow_any_instance_of(SemanticLogger::Appender::File).to receive(:log) do |_appender, log|
        normal_log_messages << log.instance_variable_get(:@message)
        normal_log_exceptions << log.exception
      end

      Rails.logger.error('oops', exception: nil)

      expect(log_failure_messages).to be_empty

      expect(normal_log_messages.any? { |msg| msg.include?('oops') }).to be true
      expect(normal_log_exceptions.any? do |e|
        e.is_a?(RuntimeError) && e.message == 'No exception provided'
      end).to be true
    end
  end

  context 'when exception is an Exception' do
    it 'logs normally' do
      log_failure_messages = []
      allow_any_instance_of(SemanticLogger::Appender::File).to receive(:error) do |_appender, message, _error|
        log_failure_messages << message
      end

      normal_log_messages = []
      normal_log_exceptions = []
      allow_any_instance_of(SemanticLogger::Appender::File).to receive(:log) do |_appender, log|
        normal_log_messages << log.instance_variable_get(:@message)
        normal_log_exceptions << log.exception
      end

      ex = RuntimeError.new('this is an error')
      Rails.logger.error('oops', exception: ex)

      expect(log_failure_messages).to be_empty

      expect(normal_log_messages.any? { |msg| msg.include?('oops') }).to be true
      expect(normal_log_exceptions.any? do |e|
        e.is_a?(RuntimeError) && e.message == 'this is an error'
      end).to be true
    end
  end
end
