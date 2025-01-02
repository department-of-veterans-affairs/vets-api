# spec/lib/datadog_logging_module_spec.rb
require 'rails_helper'
require 'datadog_logging_module'

RSpec.describe DatadogLoggingModule do
  let(:dummy_class) do
    Class.new do
      extend DatadogLoggingModule

      def self.current_user
        # This method will be mocked in the tests
      end
    end
  end

  let(:current_user) { double('User') }

  before do
    allow(dummy_class).to receive(:current_user).and_return(current_user)
  end

  describe '#datadog_Logging_Module' do
    let(:context) { 'some_context' }
    let(:message) { 'some_message' }
    let(:stack_trace) { 'some_stack_trace' }

    context 'when the feature toggle is enabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:virtual_agent_enable_datadog_logging, current_user).and_return(true)
      end

      it 'logs that the Datadog flipper is enabled' do
        error_details = { message: message, backtrace: stack_trace }

        expect(Rails.logger).to receive(:error).with(context, error_details)
        dummy_class.datadog_Logging_Module(context, message, stack_trace)
      end

    end

    context 'when the feature toggle is disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:virtual_agent_enable_datadog_logging, current_user).and_return(false)
      end

      it 'the method does not log the error to Datadog' do
        expect(Rails.logger).not_to receive(:error)
        dummy_class.datadog_Logging_Module(context, message, stack_trace)
      end
    end
  end
end