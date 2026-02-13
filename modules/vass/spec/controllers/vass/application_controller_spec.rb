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

    it 'defines handle_service_error method' do
      expect(controller.private_methods).to include(:handle_service_error)
    end

    it 'defines handle_vass_api_error method' do
      expect(controller.private_methods).to include(:handle_vass_api_error)
    end

    it 'defines handle_redis_error method' do
      expect(controller.private_methods).to include(:handle_redis_error)
    end

    it 'defines handle_serialization_error method' do
      expect(controller.private_methods).to include(:handle_serialization_error)
    end

    it 'defines render_error_response method' do
      expect(controller.private_methods).to include(:render_error_response)
    end

    it 'defines log_safe_error method' do
      expect(controller.private_methods).to include(:log_safe_error)
    end

    it 'defines handle_unexpected_error method' do
      expect(controller.private_methods).to include(:handle_unexpected_error)
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

    it 'rescues from Vass::Errors::SerializationError' do
      handlers = Vass::ApplicationController.rescue_handlers
      serialization_handler = handlers.find { |h| h.first == 'Vass::Errors::SerializationError' }
      expect(serialization_handler).not_to be_nil
    end

    it 'rescues from StandardError as catch-all' do
      handlers = Vass::ApplicationController.rescue_handlers
      standard_error_handler = handlers.find { |h| h.first == 'StandardError' }
      expect(standard_error_handler).not_to be_nil
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
      context 'with whitelisted error message' do
        let(:exception) { Vass::Errors::AuthenticationError.new('Token has expired') }

        it 'renders 401 unauthorized status' do
          expect(controller).to receive(:render).with(
            hash_including(status: :unauthorized)
          )

          controller.send(:handle_authentication_error, exception)
        end

        it 'renders the whitelisted message' do
          expect(controller).to receive(:render).with(
            hash_including(
              json: hash_including(
                errors: array_including(
                  hash_including(
                    title: 'Authentication Error',
                    detail: 'Token has expired',
                    code: 'unauthorized'
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
            expect(log_data['action']).to eq('test_action')
            expect(log_data['error_type']).to eq('authentication_error')
            expect(log_data['exception_class']).to eq('Vass::Errors::AuthenticationError')
            expect(log_data['controller']).to eq('test_controller')
            expect(log_data['timestamp']).to be_present
          end

          controller.send(:handle_authentication_error, exception)
        end
      end

      context 'with non-whitelisted error message' do
        let(:exception) { Vass::Errors::AuthenticationError.new("Failed for user #{SecureRandom.uuid}") }

        it 'renders generic fallback message to prevent PII leakage' do
          expect(controller).to receive(:render).with(
            hash_including(
              json: hash_including(
                errors: array_including(
                  hash_including(
                    detail: 'Unable to authenticate request'
                  )
                )
              )
            )
          )

          controller.send(:handle_authentication_error, exception)
        end
      end

      it 'logs error without PHI' do
        exception = Vass::Errors::AuthenticationError.new('Token has expired')
        expect(Rails.logger).to receive(:error) do |log_message|
          log_data = JSON.parse(log_message)
          expect(log_data['service']).to eq('vass')
          expect(log_data['action']).to eq('test_action')
          expect(log_data['error_type']).to eq('authentication_error')
          expect(log_data['exception_class']).to eq('Vass::Errors::AuthenticationError')
          expect(log_data['controller']).to eq('test_controller')
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

      it 'renders JSON:API error format with generic message' do
        expect(controller).to receive(:render).with(
          hash_including(
            json: hash_including(
              errors: array_including(
                hash_including(
                  title: 'Service Unavailable',
                  detail: 'The service is temporarily unavailable. Please try again later.',
                  code: 'service_unavailable'
                )
              )
            )
          )
        )

        controller.send(:handle_redis_error, exception)
      end
    end

    # RateLimitError and VANotify::Error are handled locally in SessionsController,
    # so no rescue_from handlers exist in ApplicationController for these.

    describe '#handle_serialization_error' do
      let(:exception) { Vass::Errors::SerializationError.new('Test error') }

      it 'renders 500 internal server error status' do
        expect(controller).to receive(:render).with(
          hash_including(status: :internal_server_error)
        )

        controller.send(:handle_serialization_error, exception)
      end

      it 'renders JSON:API error format' do
        expect(controller).to receive(:render).with(
          hash_including(
            json: hash_including(
              errors: array_including(
                hash_including(
                  title: 'Internal Server Error',
                  detail: 'Unable to complete request due to an internal error',
                  code: 'serialization_error'
                )
              )
            )
          )
        )

        controller.send(:handle_serialization_error, exception)
      end
    end

    describe '#camelize_keys' do
      it 'raises SerializationError on TypeError' do
        bad_hash = { key: 'value' }
        allow(bad_hash).to receive(:transform_keys).and_raise(TypeError, 'no implicit conversion')

        expect { controller.send(:camelize_keys, bad_hash) }
          .to raise_error(Vass::Errors::SerializationError, /Failed to serialize response/)
      end

      it 'raises SerializationError on Encoding::UndefinedConversionError' do
        bad_hash = { key: 'value' }
        allow(bad_hash).to receive(:transform_keys).and_raise(
          Encoding::UndefinedConversionError, 'invalid byte sequence'
        )

        expect { controller.send(:camelize_keys, bad_hash) }
          .to raise_error(Vass::Errors::SerializationError, /Failed to serialize response/)
      end

      it 'raises SerializationError on NoMethodError' do
        bad_hash = { key: 'value' }
        allow(bad_hash).to receive(:transform_keys).and_raise(NoMethodError, 'undefined method')

        expect { controller.send(:camelize_keys, bad_hash) }
          .to raise_error(Vass::Errors::SerializationError, /Failed to serialize response/)
      end
    end

    describe '#log_safe_error' do
      it 'logs error metadata without PHI using log_vass_event' do
        expect(Rails.logger).to receive(:error) do |log_message|
          log_data = JSON.parse(log_message)
          expect(log_data['service']).to eq('vass')
          expect(log_data['action']).to eq('test_action')
          expect(log_data['error_type']).to eq('test_error')
          expect(log_data['exception_class']).to eq('TestException')
          expect(log_data['controller']).to eq('test_controller')
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

    describe '#handle_unexpected_error' do
      let(:exception) { StandardError.new('Unexpected test error') }

      it 'logs error to Rails.logger' do
        expect(Rails.logger).to receive(:error) do |log_message|
          log_data = JSON.parse(log_message)
          expect(log_data['service']).to eq('vass')
          expect(log_data['action']).to eq('test_action')
          expect(log_data['error_type']).to eq('unexpected_error')
          expect(log_data['error_class']).to eq('StandardError')
          expect(log_data['controller']).to eq('test_controller')
        end

        expect { controller.send(:handle_unexpected_error, exception) }.to raise_error(StandardError)
      end

      it 're-raises the exception for global handler' do
        allow(Rails.logger).to receive(:error)

        expect { controller.send(:handle_unexpected_error, exception) }.to raise_error(StandardError)
      end

      it 'logs the specific error class name' do
        custom_error = NoMethodError.new('undefined method')

        expect(Rails.logger).to receive(:error) do |log_message|
          log_data = JSON.parse(log_message)
          expect(log_data['error_class']).to eq('NoMethodError')
        end

        expect { controller.send(:handle_unexpected_error, custom_error) }.to raise_error(NoMethodError)
      end
    end
  end
end
