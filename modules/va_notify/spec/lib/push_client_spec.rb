# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VaNotify::PushClient do
  let(:api_key) { 'test-key-92bf7f4b-4d65-47d1-9bbe-9ef31708141c-Ql3GPjQ20gNx6caxK9mXz9C78tybRMr-lodQCw3z7cLXsfBr3a_jYEjOINmCE1RAx-UQm0gTeSoKUsY_iT431w' }
  let(:callback_options) do
    {
      callback_klass: 'TestCallback',
      callback_metadata: { notification_type: 'push' }
    }
  end
  let(:client) { described_class.new(api_key, callback_options) }

  describe '#initialize' do
    context 'with API key parsing' do
      it 'sets the service_id and secret_token from parsed API key' do
        expect(client.service_id).to eq('caxK9mXz9C78tybRMr-lodQCw3z7cLXsfBr3')
        expect(client.secret_token).to eq('_jYEjOINmCE1RAx-UQm0gTeSoKUsY_iT431w')
      end

      it 'sets callback_options' do
        expect(client.callback_options).to eq(callback_options)
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
        'id' => 'notification-123',
        'reference' => nil,
        'content' => { 'body' => 'Test push notification' },
        'template' => { 'id' => 'fake-template-id-1234-5678-9012-34567890abcd', 'version' => 1 }
      }
    end

    let(:mock_response) do
      instance_double(Faraday::Response, body: mock_response_body, status: 201)
    end

    before do
      # Disable request-level callbacks by default for cleaner tests
      allow(Flipper).to receive(:enabled?).with(:va_notify_request_level_callbacks).and_return(false)
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

    it 'includes callback URL when request-level callbacks are enabled' do
      allow(Flipper).to receive(:enabled?).with(:va_notify_request_level_callbacks).and_return(true)
      allow(Settings.vanotify).to receive(:callback_url).and_return('https://api.va.gov/callback')

      expected_payload = push_args.merge(callback_url: 'https://api.va.gov/callback')

      expect_any_instance_of(described_class).to receive(:perform).with(
        :post,
        'v2/notifications/push',
        expected_payload.to_json,
        anything
      )

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

  describe '#build_payload' do
    let(:args) do
      {
        mobile_app: 'VA_FLAGSHIP_APP',
        template_id: 'template-123',
        recipient_identifier: {
          id_type: 'ICN',
          id_value: '123456789'
        },
        personalisation: {
          name: 'Test User'
        }
      }
    end

    it 'builds the correct payload structure' do
      payload = JSON.parse(client.send(:build_payload, args))

      expect(payload['mobile_app']).to eq('VA_FLAGSHIP_APP')
      expect(payload['template_id']).to eq('template-123')
      expect(payload['recipient_identifier']['id_type']).to eq('ICN')
      expect(payload['recipient_identifier']['id_value']).to eq('123456789')
      expect(payload['personalisation']['name']).to eq('Test User')
    end

    it 'includes callback URL when feature flag is enabled' do
      allow(Flipper).to receive(:enabled?).with(:va_notify_request_level_callbacks).and_return(true)
      allow(Settings.vanotify).to receive(:callback_url).and_return('https://callback.url')

      payload = JSON.parse(client.send(:build_payload, args))
      expect(payload['callback_url']).to eq('https://callback.url')
    end

    it 'omits personalisation if not provided' do
      args_without_personalisation = args.except(:personalisation)
      payload = JSON.parse(client.send(:build_payload, args_without_personalisation))

      expect(payload).not_to have_key('personalisation')
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
        allow_any_instance_of(described_class).to receive(:save_error_details)
      end

      context 'when va_notify_custom_errors is enabled' do
        before do
          allow(Flipper).to receive(:enabled?).with(:va_notify_custom_errors).and_return(true)
          allow(VANotify::Error).to receive(:from_generic_error).and_return(VANotify::Error.new(400, 'Test error'))
        end

        it 'raises VANotify::Error with context' do
          expect { client.send_push(push_args) }.to raise_error(VANotify::Error)
        end
      end

      context 'when va_notify_custom_errors is disabled' do
        before do
          allow(Flipper).to receive(:enabled?).with(:va_notify_custom_errors).and_return(false)
          allow(client).to receive(:raise_backend_exception).and_raise(StandardError.new('Backend error'))
        end

        it 'raises backend exception' do
          expect(client).to receive(:raise_backend_exception).with(
            'VANOTIFY_PUSH_400',
            described_class,
            client_error
          )

          expect { client.send_push(push_args) }.to raise_error(StandardError, 'Backend error')
        end
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