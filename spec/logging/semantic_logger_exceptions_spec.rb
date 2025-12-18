# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SemanticLogger do
  before do
    SemanticLogger.default_level = :info
  end

  it 'emits an appender failure when exception is a String' do
    messages = []
    allow_any_instance_of(SemanticLogger::Appender::File).to receive(:error) do |_appender, message, _error|
      messages << message
    end

    Rails.logger.error('oops', exception: 'not an exception')

    messages.each do |msg|
      expect(msg).not_to include("NoMethodError: undefined method `message' for an instance of String")
      expect(msg).not_to include('Failed to log to appender')
    end
  end
end
