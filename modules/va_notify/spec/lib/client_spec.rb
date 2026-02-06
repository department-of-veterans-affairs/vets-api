# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VaNotify::Client do
  let(:api_key) do
    'test-key-550e8400-e29b-41d4-a716-446655440000-123e4567-e89b-12d3-a456-426614174000'
  end
  let(:callback_options) do
    {
      callback_klass: 'TestCallback',
      callback_metadata: { notification_type: 'push' }
    }
  end
  let(:client) { described_class.new(api_key, callback_options) }

  describe '#initialize' do
    context 'with valid API key' do
      it 'sets the service_id and secret_token from parsed API key' do
        expect(client.service_id).to eq('550e8400-e29b-41d4-a716-446655440000')
        expect(client.secret_token).to eq('123e4567-e89b-12d3-a456-426614174000')
      end

      it 'sets callback_options' do
        expect(client.callback_options).to eq(callback_options)
      end
    end

    context 'with invalid API key format' do
      it 'raises ArgumentError when service_id is not a valid UUID' do
        # API key with invalid service_id - replace valid UUID with non-UUID of same length
        invalid_api_key = 'test-key-invalid-service-id-not-valid-uuid-123e4567-e89b-12d3-a456-426614174000'

        expect { described_class.new(invalid_api_key, callback_options) }
          .to raise_error(ArgumentError, /is not a valid uuid.*Invalid service_id format in API key/m)
      end

      it 'raises ArgumentError for invalid tokens' do
        # Test that validation is called - any invalid API key will trigger validation
        invalid_api_key = 'invalid-api-key-format'

        expect { described_class.new(invalid_api_key, callback_options) }
          .to raise_error(ArgumentError, /is not a valid uuid/)
      end

      it 'raises ArgumentError when API key is too short' do
        short_api_key = 'too-short'

        expect { described_class.new(short_api_key, callback_options) }
          .to raise_error(ArgumentError, /is not a valid uuid/)
      end
    end
  end

  describe '#send_push' do
    let(:push_args) do
      {
        mobile_app: 'VA_FLAGSHIP_APP',
        template_id: 'fake-template-id-1234-5678-9012-34567890abcd',
        recipient_identifier: {
          id_type: 'ICN',
          id_value: 'fake-icn-123456789V012345'
        },
        personalisation: {
          veteran_name: 'John Doe'
        }
      }
    end

    let(:mock_response_body) do
      {
        result: 'success'
      }
    end

    let(:mock_response) do
      instance_double(Faraday::Response, body: mock_response_body, status: 201)
    end

    before do
      allow_any_instance_of(described_class).to receive(:perform).and_return(mock_response)
    end

    it 'sends a push notification with correct payload' do
      expect_any_instance_of(described_class).to receive(:perform).with(
        :post,
        'v2/notifications/push',
        {
          mobile_app: 'VA_FLAGSHIP_APP',
          template_id: 'fake-template-id-1234-5678-9012-34567890abcd',
          recipient_identifier: {
            id_type: 'ICN',
            id_value: 'fake-icn-123456789V012345'
          },
          personalisation: {
            veteran_name: 'John Doe'
          }
        }.to_json,
        hash_including('Authorization', 'Content-Type', 'User-Agent')
      ).and_return(mock_response)

      client.send_push(push_args)
    end

    it 'sets the template_id instance variable' do
      client.send_push(push_args)
      expect(client.template_id).to eq('fake-template-id-1234-5678-9012-34567890abcd')
    end

    it 'returns the response body' do
      allow_any_instance_of(described_class).to receive(:perform).and_return(mock_response_body)

      response = client.send_push(push_args)
      expect(response).to eq(mock_response_body)
    end

    context 'when response is a Faraday::Env object' do
      let(:faraday_env) { instance_double(Faraday::Env, body: mock_response_body) }

      it 'extracts the body from the Faraday::Env' do
        allow_any_instance_of(described_class).to receive(:perform).and_return(faraday_env)
        allow(faraday_env).to receive(:is_a?).with(Faraday::Env).and_return(true)
        allow(faraday_env).to receive(:body).and_return(mock_response_body)

        response = client.send_push(push_args)
        expect(response).to eq(mock_response_body)
      end
    end
  end

  describe '#jwt_token' do
    let(:fixed_time) { Time.zone.parse('2025-10-19 10:00:00') }

    before do
      allow(Time).to receive(:now).and_return(fixed_time)
    end

    it 'generates a JWT token with correct payload' do
      token = client.send(:jwt_token)
      decoded = JWT.decode(token, client.secret_token, true, algorithm: 'HS256')[0]

      expect(decoded['iss']).to eq(client.service_id)
      expect(decoded['iat']).to eq(fixed_time.to_i)
    end

    it 'uses HS256 algorithm' do
      token = client.send(:jwt_token)
      header = JWT.decode(token, client.secret_token, true, algorithm: 'HS256')[1]

      expect(header['alg']).to eq('HS256')
    end
  end

  describe '#auth_headers' do
    it 'includes Bearer token authorization' do
      headers = client.send(:auth_headers)

      expect(headers['Authorization']).to start_with('Bearer ')
      expect(headers['Content-Type']).to eq('application/json')
      expect(headers['User-Agent']).to eq('vets-api-push-client')
    end
  end

  describe 'push API error responses' do
    let(:push_args) do
      {
        mobile_app: 'VA_FLAGSHIP_APP',
        template_id: 'template-123',
        recipient_identifier: { id_type: 'ICN', id_value: '123456789' }
      }
    end

    context 'when SMS sender ID does not exist (400)' do
      let(:error_response) do
        {
          'errors' => [
            {
              'error' => 'BadRequestError',
              'message' => 'sms_sender_id e925b547-8195-4ed2-83c5-0633a74d780a does not exist in database ' \
                           'for service id 9ffb5212-e621-45df-820d-97ee65d392ab'
            }
          ],
          'status_code' => 400
        }
      end
      let(:client_error) do
        Common::Client::Errors::ClientError.new('Bad Request', 400, error_response)
      end

      before do
        allow_any_instance_of(described_class).to receive(:perform).and_raise(client_error)
        allow_any_instance_of(described_class).to receive(:log_error_details)
      end

      it 'handles SMS sender ID not found error' do
        expect { client.send_push(push_args) }.to raise_error(VANotify::BadRequest)
      end
    end

    context 'when authentication token is missing (401)' do
      let(:error_response) do
        {
          'result' => 'error',
          'message' => {
            'token' => ['Unauthorized, authentication token must be provided']
          }
        }
      end
      let(:client_error) do
        Common::Client::Errors::ClientError.new('Unauthorized', 401, error_response)
      end

      before do
        allow_any_instance_of(described_class).to receive(:perform).and_raise(client_error)
        allow_any_instance_of(described_class).to receive(:log_error_details)
      end

      it 'handles missing authentication token error' do
        expect { client.send_push(push_args) }.to raise_error(VANotify::Unauthorized)
      end
    end

    context 'when service ID is wrong data type (403)' do
      let(:error_response) do
        {
          'errors' => [
            {
              'error' => 'AuthError',
              'message' => 'Invalid token: service id is not the right data type'
            }
          ],
          'status_code' => 403
        }
      end
      let(:client_error) do
        Common::Client::Errors::ClientError.new('Forbidden', 403, error_response)
      end

      before do
        allow_any_instance_of(described_class).to receive(:perform).and_raise(client_error)
        allow_any_instance_of(described_class).to receive(:log_error_details)
      end

      it 'handles invalid service ID data type error' do
        expect { client.send_push(push_args) }.to raise_error(VANotify::Forbidden)
      end
    end

    context 'when internal server error occurs (500)' do
      let(:error_response) do
        {
          'result' => 'error',
          'message' => 'Internal server error'
        }
      end
      let(:client_error) do
        Common::Client::Errors::ClientError.new('Internal Server Error', 500, error_response)
      end

      before do
        allow_any_instance_of(described_class).to receive(:perform).and_raise(client_error)
        allow_any_instance_of(described_class).to receive(:log_error_details)
      end

      it 'handles internal server error' do
        expect { client.send_push(push_args) }.to raise_error(VANotify::ServerError)
      end
    end

    context 'when mobile app is not initialized' do
      let(:error_response) do
        {
          'result' => 'error',
          'message' => 'Mobile app is not initialized'
        }
      end
      let(:client_error) do
        Common::Client::Errors::ClientError.new('Bad Request', 400, error_response)
      end

      before do
        allow_any_instance_of(described_class).to receive(:perform).and_raise(client_error)
        allow_any_instance_of(described_class).to receive(:log_error_details)
      end

      it 'handles mobile app not initialized error' do
        expect { client.send_push(push_args) }.to raise_error(VANotify::BadRequest)
      end
    end

    context 'when downstream service returns invalid response' do
      let(:error_response) do
        {
          'result' => 'error',
          'message' => 'Invalid response from downstream service'
        }
      end
      let(:client_error) do
        Common::Client::Errors::ClientError.new('Bad Gateway', 502, error_response)
      end

      before do
        allow_any_instance_of(described_class).to receive(:perform).and_raise(client_error)
        allow_any_instance_of(described_class).to receive(:log_error_details)
      end

      it 'handles invalid downstream service response error' do
        expect { client.send_push(push_args) }.to raise_error(VANotify::Error)
      end
    end
  end

  describe 'error handling' do
    let(:push_args) do
      {
        mobile_app: 'VA_FLAGSHIP_APP',
        template_id: 'template-123',
        recipient_identifier: { id_type: 'ICN', id_value: '123456789' }
      }
    end

    context 'when Common::Client::Errors::ClientError is raised' do
      let(:client_error) do
        Common::Client::Errors::ClientError.new('Bad Request', 400, { error: 'Invalid template' })
      end

      before do
        allow_any_instance_of(described_class).to receive(:perform).and_raise(client_error)
        allow_any_instance_of(described_class).to receive(:log_error_details)
        allow(VANotify::Error).to receive(:from_generic_error).and_return(VANotify::Error.new(400, 'Test error'))
      end

      it 'raises VANotify::Error with context' do
        expect { client.send_push(push_args) }.to raise_error(VANotify::Error)
      end
    end
  end

  describe '#sanitize_metadata' do
    it 'only includes safe keys' do
      metadata = {
        notification_type: 'push',
        form_number: '123',
        mobile_app: 'VA_APP',
        sensitive_data: 'should_be_removed',
        pii: 'personal_info'
      }

      sanitized = client.send(:sanitize_metadata, metadata)

      expect(sanitized).to eq({
                                notification_type: 'push',
                                form_number: '123',
                                mobile_app: 'VA_APP'
                              })
    end

    it 'returns nil for non-hash input' do
      expect(client.send(:sanitize_metadata, 'not a hash')).to be_nil
      expect(client.send(:sanitize_metadata, nil)).to be_nil
    end
  end
end
