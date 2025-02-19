# frozen_string_literal: true

require 'rails_helper'

module AccreditedRepresentativePortal
  # rubocop:disable Lint/ConstantDefinitionInBlock, Rails/ApplicationController
  RSpec.describe Logging, type: :controller do
    # Create a test controller class that inherits from ApplicationController
    class TestController < ActionController::Base
      include Logging
      SERVICE_NAME = 'test-service'

      def test_log_info
        log_info('Test info message', 'test.metric.info', ['test:tag'])
        render plain: 'logged'
      end

      def test_log_warn
        log_warn('Test warn message', 'test.metric.warn', ['test:tag'])
        render plain: 'logged'
      end

      def test_log_error
        log_error('Test error message', 'test.metric.error', 'TestError', ['test:tag'])
        render plain: 'logged'
      end
    end

    # Use the TestController for our tests
    controller TestController do
    end

    let(:monitor) { instance_double(MonitoringService) }

    before do
      routes.draw do
        get 'test_log_info' => 'accredited_representative_portal/test#test_log_info'
        get 'test_log_warn' => 'accredited_representative_portal/test#test_log_warn'
        get 'test_log_error' => 'accredited_representative_portal/test#test_log_error'
      end

      allow(MonitoringService).to receive(:new).and_return(monitor)
      allow(monitor).to receive(:track_event)
      allow(monitor).to receive(:track_error)
    end

    describe '#log_info' do
      it 'calls monitor.track_event with info level' do
        get :test_log_info
        expect(monitor).to have_received(:track_event)
          .with(:info, 'Test info message', 'test.metric.info', ['test:tag'])
      end
    end

    describe '#log_warn' do
      it 'calls monitor.track_event with warn level' do
        get :test_log_warn
        expect(monitor).to have_received(:track_event)
          .with(:warn, 'Test warn message', 'test.metric.warn', ['test:tag'])
      end
    end

    describe '#log_error' do
      it 'calls monitor.track_error with error level' do
        get :test_log_error
        expect(monitor).to have_received(:track_error)
          .with('Test error message', 'test.metric.error', 'TestError', ['test:tag'])
      end
    end
  end
  # rubocop:enable Lint/ConstantDefinitionInBlock, Rails/ApplicationController
end
