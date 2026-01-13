# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ErrorHandler, type: :concern do
  let(:test_controller_class) do
    Class.new(ApplicationController) do
      include ErrorHandler

      attr_accessor :current_user

      def test_action_with_service_error
        handle_service_errors('test operation') do
          raise Common::Exceptions::BackendServiceException.new('TEST_ERROR', source: 'TestService')
        end
      end

      def test_action_with_generic_error
        handle_service_errors('test operation') do
          raise StandardError, 'Something went wrong'
        end
      end

      def test_action_with_success
        handle_service_errors('test operation') do
          render json: { success: true }, status: :ok
        end
      end

      def test_successful_logging
        log_operation_success('successful operation', extra_data: 'value')
      end

      def test_action_without_backtrace
        handle_service_errors('test operation', include_backtrace: false) do
          raise StandardError, 'Something went wrong'
        end
      end
    end
  end

  let(:controller) { test_controller_class.new }
  let(:user) { create(:user, uuid: 'test-uuid-123') }

  before do
    allow(controller).to receive(:render)
    allow(Rails.logger).to receive(:info)
    allow(Rails.logger).to receive(:error)
    allow(Rails.logger).to receive(:warn)
    controller.current_user = user
  end

  describe '#handle_service_errors' do
    context 'when no errors occur' do
      it 'executes the block normally' do
        expect(controller).to receive(:render).with(json: { success: true }, status: :ok)

        controller.test_action_with_success
      end
    end

    context 'when BackendServiceException occurs' do
      before do
        controller.test_action_with_service_error
      end

      it 'logs the service error with structured data' do
        expect(Rails.logger).to have_received(:error).with(
          'test operation - service error',
          hash_including(
            user_uuid: 'test-uuid-123',
            error: 'BackendServiceException: {:source=>"TestService", :code=>"VA900"}',
            error_class: 'Common::Exceptions::BackendServiceException'
          )
        )
      end

      it 'renders service unavailable error response' do
        expect(controller).to have_received(:render).with(
          json: {
            errors: [
              {
                title: 'Service Unavailable',
                detail: 'Service is temporarily unavailable. Please try again later.',
                code: 'SERVICE_UNAVAILABLE',
                status: '503'
              }
            ]
          },
          status: :service_unavailable
        )
      end
    end

    context 'when generic error occurs' do
      before do
        controller.test_action_with_generic_error
      end

      it 'logs the unexpected error with structured data and backtrace' do
        expect(Rails.logger).to have_received(:error).with(
          'test operation - unexpected error',
          hash_including(
            user_uuid: 'test-uuid-123',
            error: 'Something went wrong',
            error_class: 'StandardError',
            backtrace: kind_of(Array)
          )
        )
      end

      it 'renders internal server error response' do
        expect(controller).to have_received(:render).with(
          json: {
            errors: [
              {
                title: 'Internal Server Error',
                detail: 'An unexpected error occurred. Please try again later.',
                code: 'INTERNAL_SERVER_ERROR',
                status: '500'
              }
            ]
          },
          status: :internal_server_error
        )
      end
    end

    context 'when include_backtrace is false' do
      it 'logs error without backtrace' do
        controller.test_action_without_backtrace

        expect(Rails.logger).to have_received(:error) do |message, log_data|
          expect(message).to eq('test operation - unexpected error')
          expect(log_data).to include(
            user_uuid: 'test-uuid-123',
            error: 'Something went wrong',
            error_class: 'StandardError'
          )
          expect(log_data).not_to have_key(:backtrace)
        end
      end
    end
  end

  describe '#log_operation_success' do
    it 'logs successful operations with structured data' do
      controller.test_successful_logging

      expect(Rails.logger).to have_received(:info).with(
        'successful operation',
        hash_including(
          user_uuid: 'test-uuid-123',
          extra_data: 'value'
        )
      )
    end
  end

  describe '#base_log_data' do
    context 'when current_user is present' do
      it 'includes user_uuid in log data' do
        log_data = controller.send(:base_log_data)
        expect(log_data).to eq({ user_uuid: 'test-uuid-123' })
      end
    end

    context 'when current_user is nil' do
      let(:controller_without_user) { test_controller_class.new }

      before do
        allow(controller_without_user).to receive(:render)
        controller_without_user.current_user = nil
      end

      it 'returns empty hash when no current_user' do
        log_data = controller_without_user.send(:base_log_data)
        expect(log_data).to eq({})
      end
    end

    context 'when controller does not respond to current_user' do
      let(:controller_class_without_user) do
        Class.new do
          include ErrorHandler

          def test_base_log_data
            base_log_data
          end
        end
      end

      let(:controller_without_user_method) { controller_class_without_user.new }

      it 'returns empty hash when current_user method does not exist' do
        log_data = controller_without_user_method.test_base_log_data
        expect(log_data).to eq({})
      end
    end
  end

  describe 'error response methods' do
    describe '#render_service_unavailable_error' do
      it 'renders correct service unavailable response' do
        controller.send(:render_service_unavailable_error)

        expect(controller).to have_received(:render).with(
          json: {
            errors: [
              {
                title: 'Service Unavailable',
                detail: 'Service is temporarily unavailable. Please try again later.',
                code: 'SERVICE_UNAVAILABLE',
                status: '503'
              }
            ]
          },
          status: :service_unavailable
        )
      end
    end

    describe '#render_internal_server_error' do
      it 'renders correct internal server error response' do
        controller.send(:render_internal_server_error)

        expect(controller).to have_received(:render).with(
          json: {
            errors: [
              {
                title: 'Internal Server Error',
                detail: 'An unexpected error occurred. Please try again later.',
                code: 'INTERNAL_SERVER_ERROR',
                status: '500'
              }
            ]
          },
          status: :internal_server_error
        )
      end
    end
  end

  describe 'integration with controller' do
    let(:integration_controller_class) do
      Class.new(ApplicationController) do
        include ErrorHandler

        attr_accessor :current_user

        def service_action
          handle_service_errors('service operation') do
            # Simulate some successful service operation
            log_operation_success('service completed successfully', result_count: 5)
            render json: { data: 'success' }, status: :ok
          end
        end

        def error_action
          handle_service_errors('error operation') do
            raise Common::Exceptions::BackendServiceException.new('Service down')
          end
        end
      end
    end

    let(:integration_controller) { integration_controller_class.new }

    before do
      allow(integration_controller).to receive(:render)
      allow(Rails.logger).to receive(:info)
      allow(Rails.logger).to receive(:error)
      allow(Rails.logger).to receive(:warn)
      integration_controller.current_user = user
    end

    it 'works seamlessly with controller actions' do
      integration_controller.service_action

      expect(Rails.logger).to have_received(:info).with(
        'service completed successfully',
        hash_including(user_uuid: 'test-uuid-123', result_count: 5)
      )

      expect(integration_controller).to have_received(:render).with(
        json: { data: 'success' }, status: :ok
      )
    end

    it 'handles errors in controller actions' do
      integration_controller.error_action

      expect(Rails.logger).to have_received(:error).with(
        'error operation - service error',
        hash_including(
          user_uuid: 'test-uuid-123',
          error: 'BackendServiceException: {:code=>"VA900"}'
        )
      )

      expect(integration_controller).to have_received(:render).with(
        json: {
          errors: [
            {
              title: 'Service Unavailable',
              detail: 'Service is temporarily unavailable. Please try again later.',
              code: 'SERVICE_UNAVAILABLE',
              status: '503'
            }
          ]
        },
        status: :service_unavailable
      )
    end
  end
end
