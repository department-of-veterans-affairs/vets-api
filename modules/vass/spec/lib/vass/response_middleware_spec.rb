# frozen_string_literal: true

require 'rails_helper'
require 'vass/response_middleware'

# Define ServiceException for specs (normally loaded via Client)
module Vass
  class ServiceException < Common::Exceptions::BackendServiceException; end unless defined?(Vass::ServiceException)
end

# NOTE: This middleware runs AFTER the snakecase middleware in the Faraday stack.
# Test data uses snake_case keys (correlation_id, time_stamp) to reflect what
# the middleware receives after snakecase transformation.
describe Vass::ResponseMiddleware do
  let(:middleware) { described_class.new(->(env) { env }) }

  def create_env(status: 200, content_type: 'application/json; charset=utf-8', response_headers: nil, body: {})
    env = OpenStruct.new
    env.status = status
    env.response_headers = response_headers || { 'content-type' => content_type }
    env.body = body
    env
  end

  describe '#on_complete' do
    context 'when response is HTTP 200 with success: true' do
      it 'does not raise an exception' do
        env = create_env(
          body: {
            'success' => true,
            'message' => nil,
            'data' => { 'appointment_id' => 'test-123' },
            'correlation_id' => 'req123',
            'time_stamp' => '2025-12-02T12:00:00Z'
          }
        )

        expect { middleware.on_complete(env) }.not_to raise_error
      end
    end

    context 'when response is HTTP 200 with success: false' do
      context 'with Missing Parameters error' do
        it 'raises Vass::ServiceException with status 400' do
          env = create_env(
            body: {
              'success' => false,
              'message' => 'Missing Parameters',
              'data' => nil,
              'correlation_id' => 'req123',
              'time_stamp' => '2025-12-02T12:00:00Z'
            }
          )

          expect { middleware.on_complete(env) }.to raise_error(
            Vass::ServiceException
          ) do |exception|
            expect(exception.original_status).to eq(400)
            expect(exception.original_body).to eq(env[:body])
          end
        end
      end

      context 'with invalid GUID format error' do
        it 'raises Vass::ServiceException with status 422' do
          env = create_env(
            body: {
              'success' => false,
              'message' => 'Provided veteranId does not have a valid GUID format',
              'data' => nil,
              'correlation_id' => 'req123',
              'time_stamp' => '2025-12-02T12:00:00Z'
            }
          )

          expect { middleware.on_complete(env) }.to raise_error(
            Vass::ServiceException
          ) do |exception|
            expect(exception.original_status).to eq(422)
          end
        end
      end

      context 'with not found error' do
        it 'raises Vass::ServiceException with status 404' do
          env = create_env(
            body: {
              'success' => false,
              'message' => 'Appointment not found',
              'data' => nil,
              'correlation_id' => 'req123',
              'time_stamp' => '2025-12-02T12:00:00Z'
            }
          )

          expect { middleware.on_complete(env) }.to raise_error(
            Vass::ServiceException
          ) do |exception|
            expect(exception.original_status).to eq(404)
          end
        end
      end

      context 'with invalid date range error' do
        it 'raises Vass::ServiceException with status 422' do
          env = create_env(
            body: {
              'success' => false,
              'message' => 'The end date must be later than the start date. Please select a valid date range.',
              'data' => nil,
              'correlation_id' => 'req123',
              'time_stamp' => '2025-12-02T12:00:00Z'
            }
          )

          expect { middleware.on_complete(env) }.to raise_error(
            Vass::ServiceException
          ) do |exception|
            expect(exception.original_status).to eq(422)
          end
        end
      end

      context 'with time slot not available error' do
        it 'raises Vass::ServiceException with status 422' do
          env = create_env(
            body: {
              'success' => false,
              'message' => 'The selected time-slot is not available',
              'data' => nil,
              'correlation_id' => 'req123',
              'time_stamp' => '2025-12-02T12:00:00Z'
            }
          )

          expect { middleware.on_complete(env) }.to raise_error(
            Vass::ServiceException
          ) do |exception|
            expect(exception.original_status).to eq(422)
          end
        end
      end

      context 'with processor error' do
        it 'raises Vass::ServiceException with status 502' do
          env = create_env(
            body: {
              'success' => false,
              'message' => 'GetVeteranAppointmentProcessor Error.',
              'data' => nil,
              'correlation_id' => 'req123',
              'time_stamp' => '2025-12-02T12:00:00Z'
            }
          )

          expect { middleware.on_complete(env) }.to raise_error(
            Vass::ServiceException
          ) do |exception|
            expect(exception.original_status).to eq(502)
          end
        end
      end

      context 'with unknown error message' do
        it 'raises Vass::ServiceException with status 502' do
          env = create_env(
            body: {
              'success' => false,
              'message' => 'Unknown error occurred',
              'data' => nil,
              'correlation_id' => 'req123',
              'time_stamp' => '2025-12-02T12:00:00Z'
            }
          )

          expect { middleware.on_complete(env) }.to raise_error(
            Vass::ServiceException
          ) do |exception|
            expect(exception.original_status).to eq(502)
          end
        end
      end

      context 'with blank error message' do
        it 'raises Vass::ServiceException with status 502' do
          env = create_env(
            body: {
              'success' => false,
              'message' => '',
              'data' => nil,
              'correlation_id' => 'req123',
              'time_stamp' => '2025-12-02T12:00:00Z'
            }
          )

          expect { middleware.on_complete(env) }.to raise_error(
            Vass::ServiceException
          ) do |exception|
            expect(exception.original_status).to eq(502)
          end
        end
      end

      it 'logs to Sentry with safe context' do
        env = create_env(
          body: {
            'success' => false,
            'message' => 'Test error',
            'data' => nil,
            'correlation_id' => 'req123',
            'time_stamp' => '2025-12-02T12:00:00Z'
          }
        )

        expect(Sentry).to receive(:set_extras).with(
          vass_error: true,
          correlation_id: 'req123',
          timestamp: '2025-12-02T12:00:00Z',
          has_message: true
        )

        expect { middleware.on_complete(env) }.to raise_error(
          Vass::ServiceException
        )
      end

      it 'logs StatsD metrics for HTTP 200 errors' do
        env = create_env(
          body: {
            'success' => false,
            'message' => 'Missing Parameters',
            'data' => nil,
            'correlation_id' => 'req123',
            'time_stamp' => '2025-12-02T12:00:00Z'
          }
        )

        expect(StatsD).to receive(:increment).with(
          'api.vass.http_200_errors',
          tags: ['error_status:400', 'service:vass']
        )

        expect { middleware.on_complete(env) }.to raise_error(
          Vass::ServiceException
        )
      end

      it 'logs different status codes in StatsD metrics' do
        test_cases = [
          { message: 'Missing Parameters', status: 400 },
          { message: 'Appointment not found', status: 404 },
          { message: 'Invalid GUID format', status: 422 },
          { message: 'Unknown error', status: 502 }
        ]

        test_cases.each do |test_case|
          env = create_env(
            body: {
              'success' => false,
              'message' => test_case[:message],
              'data' => nil,
              'correlation_id' => 'req123',
              'time_stamp' => '2025-12-02T12:00:00Z'
            }
          )

          expect(StatsD).to receive(:increment).with(
            'api.vass.http_200_errors',
            tags: ["error_status:#{test_case[:status]}", 'service:vass']
          )

          expect { middleware.on_complete(env) }.to raise_error(
            Vass::ServiceException
          )
        end
      end
    end

    context 'when response is not HTTP 200' do
      it 'does not intercept 404 responses' do
        env = create_env(
          status: 404,
          body: { 'error' => 'Not found' }
        )

        expect { middleware.on_complete(env) }.not_to raise_error
      end

      it 'does not intercept 500 responses' do
        env = create_env(
          status: 500,
          body: { 'error' => 'Internal server error' }
        )

        expect { middleware.on_complete(env) }.not_to raise_error
      end
    end

    context 'when response is not JSON' do
      it 'does not process XML responses' do
        env = create_env(
          response_headers: { 'content-type' => 'text/xml' },
          body: '<error>Test</error>'
        )

        expect { middleware.on_complete(env) }.not_to raise_error
      end

      it 'does not process HTML responses' do
        env = create_env(
          response_headers: { 'content-type' => 'text/html' },
          body: '<html><body>Error</body></html>'
        )

        expect { middleware.on_complete(env) }.not_to raise_error
      end
    end

    context 'when response body is not a Hash' do
      it 'does not process string responses' do
        env = create_env(
          body: 'plain text response'
        )

        expect { middleware.on_complete(env) }.not_to raise_error
      end

      it 'does not process array responses' do
        env = create_env(
          body: [{ 'success' => false }]
        )

        expect { middleware.on_complete(env) }.not_to raise_error
      end
    end

    context 'when body does not have success field' do
      it 'does not raise an exception' do
        env = create_env(
          body: {
            'message' => 'Test message',
            'data' => { 'value' => 123 }
          }
        )

        expect { middleware.on_complete(env) }.not_to raise_error
      end
    end
  end

  describe 'error message mapping' do
    let(:test_cases) do
      {
        'Missing Parameters' => 400,
        'Error Missing Parameters' => 400,
        'Provided veteranId does not have a valid GUID format' => 422,
        'Provided appointmentId does not have a valid GUID format' => 422,
        'Invalid format' => 422,
        'Appointment not found' => 404,
        'Resource does not exist' => 404,
        'Search Miss' => 404,
        'The selected time-slot is not available' => 422,
        'Service unavailable' => 422,
        'Invalid Booking Period Requested.' => 422,
        'The end date must be later than the start date' => 422,
        'Error Loading Call Center Hours' => 502,
        'GetVeteranAppointmentProcessor Error.' => 502,
        'Unknown error' => 502,
        '' => 502
      }
    end

    it 'maps error messages to correct HTTP status codes' do
      test_cases.each do |message, expected_status|
        env = create_env(
          body: {
            'success' => false,
            'message' => message,
            'data' => nil,
            'correlation_id' => 'req123',
            'time_stamp' => '2025-12-02T12:00:00Z'
          }
        )

        expect { middleware.on_complete(env) }.to raise_error(
          Vass::ServiceException
        ) do |exception|
          expect(exception.original_status).to eq(expected_status),
                                               "Expected #{message.inspect} to map to #{expected_status}, " \
                                               "got #{exception.original_status}"
        end
      end
    end
  end
end
