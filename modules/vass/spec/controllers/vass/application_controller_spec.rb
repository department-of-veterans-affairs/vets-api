# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Vass::ApplicationController, type: :controller do
  describe 'inheritance and configuration' do
    it 'inherits from ::ApplicationController' do
      expect(Vass::ApplicationController.superclass).to eq(ApplicationController)
    end

    it 'includes ExceptionHandling concern from parent' do
      expect(Vass::ApplicationController.ancestors).to include(ExceptionHandling)
    end

    it 'configures service tag to vass' do
      # Service tag is set via the service_tag method from Traceable concern
      # We verify the instance variable is set on the class
      expect(Vass::ApplicationController.trace_service_tag).to eq('vass')
    end
  end

  describe 'error handling methods' do
    let(:controller) { Vass::ApplicationController.new }

    it 'defines cors_preflight method' do
      expect(controller).to respond_to(:cors_preflight)
    end

    it 'defines handle_authentication_error method' do
      expect(controller.private_methods).to include(:handle_authentication_error)
    end

    it 'defines handle_not_found_error method' do
      expect(controller.private_methods).to include(:handle_not_found_error)
    end

    it 'defines handle_validation_error method' do
      expect(controller.private_methods).to include(:handle_validation_error)
    end

    it 'defines handle_service_error method' do
      expect(controller.private_methods).to include(:handle_service_error)
    end

    it 'defines handle_vass_api_error method' do
      expect(controller.private_methods).to include(:handle_vass_api_error)
    end

    it 'defines handle_redis_error method' do
      expect(controller.private_methods).to include(:handle_redis_error)
    end

    it 'defines render_error_response method' do
      expect(controller.private_methods).to include(:render_error_response)
    end

    it 'defines log_safe_error method' do
      expect(controller.private_methods).to include(:log_safe_error)
    end
  end

  describe 'rescue_from handlers' do
    it 'rescues from Vass::Errors::AuthenticationError' do
      handlers = Vass::ApplicationController.rescue_handlers
      auth_error_handler = handlers.find { |h| h.first == 'Vass::Errors::AuthenticationError' }
      expect(auth_error_handler).not_to be_nil
    end

    it 'rescues from Vass::Errors::NotFoundError' do
      handlers = Vass::ApplicationController.rescue_handlers
      not_found_handler = handlers.find { |h| h.first == 'Vass::Errors::NotFoundError' }
      expect(not_found_handler).not_to be_nil
    end

    it 'rescues from Vass::Errors::ValidationError' do
      handlers = Vass::ApplicationController.rescue_handlers
      validation_handler = handlers.find { |h| h.first == 'Vass::Errors::ValidationError' }
      expect(validation_handler).not_to be_nil
    end

    it 'rescues from Vass::Errors::ServiceError' do
      handlers = Vass::ApplicationController.rescue_handlers
      service_handler = handlers.find { |h| h.first == 'Vass::Errors::ServiceError' }
      expect(service_handler).not_to be_nil
    end

    it 'rescues from Vass::Errors::VassApiError' do
      handlers = Vass::ApplicationController.rescue_handlers
      api_handler = handlers.find { |h| h.first == 'Vass::Errors::VassApiError' }
      expect(api_handler).not_to be_nil
    end

    it 'rescues from Vass::Errors::RedisError' do
      handlers = Vass::ApplicationController.rescue_handlers
      redis_handler = handlers.find { |h| h.first == 'Vass::Errors::RedisError' }
      expect(redis_handler).not_to be_nil
    end
  end

  describe 'error handler behavior' do
    let(:controller) { Vass::ApplicationController.new }

    before do
      allow(controller).to receive_messages(controller_name: 'test_controller', action_name: 'test_action')
      allow(controller).to receive(:render)
      allow(Rails.logger).to receive(:error)
    end

    describe '#handle_authentication_error' do
      let(:exception) { Vass::Errors::AuthenticationError.new('Test error') }

      it 'renders 401 unauthorized status' do
        expect(controller).to receive(:render).with(
          hash_including(status: :unauthorized)
        )

        controller.send(:handle_authentication_error, exception)
      end

      it 'renders JSON:API error format' do
        expect(controller).to receive(:render).with(
          hash_including(
            json: hash_including(
              errors: array_including(
                hash_including(
                  title: 'Authentication Error',
                  detail: 'Unable to authenticate request',
                  code: 'authentication_error'
                )
              )
            )
          )
        )

        controller.send(:handle_authentication_error, exception)
      end

      it 'logs error without PHI' do
        expect(Rails.logger).to receive(:error) do |log_message|
          log_data = JSON.parse(log_message)
          expect(log_data['service']).to eq('vass')
          expect(log_data['error_type']).to eq('authentication_error')
          expect(log_data['exception_class']).to eq('Vass::Errors::AuthenticationError')
          expect(log_data['controller']).to eq('test_controller')
          expect(log_data['action']).to eq('test_action')
          expect(log_data['timestamp']).to be_present
        end

        controller.send(:handle_authentication_error, exception)
      end
    end

    describe '#handle_not_found_error' do
      let(:exception) { Vass::Errors::NotFoundError.new('Test error') }

      it 'renders 404 not found status' do
        expect(controller).to receive(:render).with(
          hash_including(status: :not_found)
        )

        controller.send(:handle_not_found_error, exception)
      end

      it 'renders JSON:API error format' do
        expect(controller).to receive(:render).with(
          hash_including(
            json: hash_including(
              errors: array_including(
                hash_including(
                  title: 'Not Found',
                  detail: 'Appointment not found',
                  code: 'appointment_not_found'
                )
              )
            )
          )
        )

        controller.send(:handle_not_found_error, exception)
      end
    end

    describe '#handle_validation_error' do
      let(:exception) { Vass::Errors::ValidationError.new('Test error') }

      it 'renders 422 unprocessable entity status' do
        expect(controller).to receive(:render).with(
          hash_including(status: :unprocessable_entity)
        )

        controller.send(:handle_validation_error, exception)
      end

      it 'renders JSON:API error format' do
        expect(controller).to receive(:render).with(
          hash_including(
            json: hash_including(
              errors: array_including(
                hash_including(
                  title: 'Validation Error',
                  detail: 'The request failed validation',
                  code: 'validation_error'
                )
              )
            )
          )
        )

        controller.send(:handle_validation_error, exception)
      end
    end

    describe '#handle_service_error' do
      let(:exception) { Vass::Errors::ServiceError.new('Test error') }

      it 'renders 503 service unavailable status' do
        expect(controller).to receive(:render).with(
          hash_including(status: :service_unavailable)
        )

        controller.send(:handle_service_error, exception)
      end

      it 'renders JSON:API error format' do
        expect(controller).to receive(:render).with(
          hash_including(
            json: hash_including(
              errors: array_including(
                hash_including(
                  title: 'Service Error',
                  detail: 'The service is temporarily unavailable',
                  code: 'service_error'
                )
              )
            )
          )
        )

        controller.send(:handle_service_error, exception)
      end
    end

    describe '#handle_vass_api_error' do
      let(:exception) { Vass::Errors::VassApiError.new('Test error') }

      it 'renders 502 bad gateway status' do
        expect(controller).to receive(:render).with(
          hash_including(status: :bad_gateway)
        )

        controller.send(:handle_vass_api_error, exception)
      end

      it 'renders JSON:API error format' do
        expect(controller).to receive(:render).with(
          hash_including(
            json: hash_including(
              errors: array_including(
                hash_including(
                  title: 'VASS API Error',
                  detail: 'Unable to process request with appointment service',
                  code: 'vass_api_error'
                )
              )
            )
          )
        )

        controller.send(:handle_vass_api_error, exception)
      end
    end

    describe '#handle_redis_error' do
      let(:exception) { Vass::Errors::RedisError.new('Test error') }

      it 'renders 503 service unavailable status' do
        expect(controller).to receive(:render).with(
          hash_including(status: :service_unavailable)
        )

        controller.send(:handle_redis_error, exception)
      end

      it 'renders JSON:API error format' do
        expect(controller).to receive(:render).with(
          hash_including(
            json: hash_including(
              errors: array_including(
                hash_including(
                  title: 'Cache Error',
                  detail: 'The caching service is temporarily unavailable',
                  code: 'redis_error'
                )
              )
            )
          )
        )

        controller.send(:handle_redis_error, exception)
      end
    end

    describe '#handle_rate_limit_error' do
      let(:exception) { Vass::Errors::RateLimitError.new('Test error') }

      it 'renders 429 too many requests status' do
        expect(controller).to receive(:render).with(
          hash_including(status: :too_many_requests)
        )

        controller.send(:handle_rate_limit_error, exception)
      end

      it 'renders JSON:API error format' do
        expect(controller).to receive(:render).with(
          hash_including(
            json: hash_including(
              errors: array_including(
                hash_including(
                  title: 'Rate Limit Exceeded',
                  detail: 'Too many requests. Please try again later',
                  code: 'rate_limit_error'
                )
              )
            )
          )
        )

        controller.send(:handle_rate_limit_error, exception)
      end
    end

    describe '#handle_vanotify_error' do
      it 'maps 400 to bad_request' do
        exception = VANotify::Error.new(400, 'Bad request')
        expect(controller).to receive(:render).with(
          hash_including(status: :bad_request)
        )

        controller.send(:handle_vanotify_error, exception)
      end

      it 'maps 401 to unauthorized' do
        exception = VANotify::Error.new(401, 'Unauthorized')
        expect(controller).to receive(:render).with(
          hash_including(status: :unauthorized)
        )

        controller.send(:handle_vanotify_error, exception)
      end

      it 'maps 403 to unauthorized' do
        exception = VANotify::Error.new(403, 'Forbidden')
        expect(controller).to receive(:render).with(
          hash_including(status: :unauthorized)
        )

        controller.send(:handle_vanotify_error, exception)
      end

      it 'maps 404 to not_found' do
        exception = VANotify::Error.new(404, 'Not found')
        expect(controller).to receive(:render).with(
          hash_including(status: :not_found)
        )

        controller.send(:handle_vanotify_error, exception)
      end

      it 'maps 429 to too_many_requests' do
        exception = VANotify::Error.new(429, 'Too many requests')
        expect(controller).to receive(:render).with(
          hash_including(status: :too_many_requests)
        )

        controller.send(:handle_vanotify_error, exception)
      end

      it 'maps 500 to bad_gateway' do
        exception = VANotify::Error.new(500, 'Server error')
        expect(controller).to receive(:render).with(
          hash_including(status: :bad_gateway)
        )

        controller.send(:handle_vanotify_error, exception)
      end

      it 'maps 502 to bad_gateway' do
        exception = VANotify::Error.new(502, 'Bad gateway')
        expect(controller).to receive(:render).with(
          hash_including(status: :bad_gateway)
        )

        controller.send(:handle_vanotify_error, exception)
      end

      it 'maps 503 to bad_gateway' do
        exception = VANotify::Error.new(503, 'Service unavailable')
        expect(controller).to receive(:render).with(
          hash_including(status: :bad_gateway)
        )

        controller.send(:handle_vanotify_error, exception)
      end

      it 'maps unknown status codes to service_unavailable' do
        exception = VANotify::Error.new(999, 'Unknown error')
        expect(controller).to receive(:render).with(
          hash_including(status: :service_unavailable)
        )

        controller.send(:handle_vanotify_error, exception)
      end

      it 'renders JSON:API error format' do
        exception = VANotify::Error.new(500, 'Server error')
        expect(controller).to receive(:render).with(
          hash_including(
            json: hash_including(
              errors: array_including(
                hash_including(
                  title: 'Notification Service Error',
                  detail: 'Unable to send notification. Please try again later',
                  code: 'notification_error'
                )
              )
            )
          )
        )

        controller.send(:handle_vanotify_error, exception)
      end
    end

    describe '#log_safe_error' do
      it 'logs error metadata without PHI' do
        expect(Rails.logger).to receive(:error) do |log_message|
          log_data = JSON.parse(log_message)
          expect(log_data['service']).to eq('vass')
          expect(log_data['error_type']).to eq('test_error')
          expect(log_data['exception_class']).to eq('TestException')
          expect(log_data['controller']).to eq('test_controller')
          expect(log_data['action']).to eq('test_action')
          expect(log_data['timestamp']).to be_present
        end

        controller.send(:log_safe_error, 'test_error', 'TestException')
      end

      it 'includes timestamp' do
        Timecop.freeze(Time.zone.parse('2026-01-06T12:00:00Z')) do
          expect(Rails.logger).to receive(:error) do |log_message|
            log_data = JSON.parse(log_message)
            expect(log_data['timestamp']).to eq('2026-01-06T12:00:00Z')
          end

          controller.send(:log_safe_error, 'test_error', 'TestException')
        end
      end
    end

    describe '#render_error_response' do
      it 'renders JSON:API error format' do
        expect(controller).to receive(:render).with(
          json: {
            errors: [{
              title: 'Test Title',
              detail: 'Test Detail',
              code: '500'
            }]
          },
          status: :internal_server_error
        )

        controller.send(:render_error_response,
                        title: 'Test Title',
                        detail: 'Test Detail',
                        status: :internal_server_error)
      end

      it 'converts status symbol to numeric code' do
        expect(controller).to receive(:render).with(
          hash_including(
            json: hash_including(
              errors: array_including(
                hash_including(code: '404')
              )
            )
          )
        )

        controller.send(:render_error_response,
                        title: 'Not Found',
                        detail: 'Resource not found',
                        status: :not_found)
      end
    end
  end
end
