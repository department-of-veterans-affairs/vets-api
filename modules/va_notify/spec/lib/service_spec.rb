# frozen_string_literal: true

require 'rails_helper'
require 'va_notify/service'

describe VaNotify::Service do
  before(:example, test_service: false) do
    test_base_url = 'http://fakeapi.com'
    allow_any_instance_of(VaNotify::Configuration).to receive(:base_path).and_return(test_base_url)
  end

  let(:test_api_key) { 'test-aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa-bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb' }
  let(:test_api_key_secret_token) { 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb' }
  let(:send_email_parameters) do
    {
      id: '975312468',
      email_address: 'test@email.com',
      template_id: '1234',
      personalisation: {
        foo: 'bar'
      }
    }
  end
  let(:send_sms_parameters) do
    {
      id: '864213579',
      phone_number: '+19876543210',
      template_id: '1234',
      sms_sender_id: '9876',
      personalisation: {
        foo: 'bar'
      }
    }
  end

  describe 'service initialization', :test_service do
    let(:notification_client) { double('Notifications::Client') }
    let(:va_notify_client) { double('VaNotify::Client') }

    it 'api key based on service and client is called with expected parameters' do
      test_service_api_key = 'fa80e418-ff49-445c-a29b-92c04a181207-7aaec57c-2dc9-4d31-8f5c-7225fe79516a'
      test_service_base_url = 'https://fakishapi.com'
      parameters = test_service_api_key, test_service_base_url
      with_settings(Settings.vanotify,
                    services: {
                      test_service: {
                        api_key: test_service_api_key
                      }
                    },
                    client_url: test_service_base_url) do
        allow(Notifications::Client).to receive(:new).with(*parameters).and_return(notification_client)
        allow(VaNotify::Client).to receive(:new).with(test_service_api_key, {}).and_return(va_notify_client)
        VaNotify::Service.new(test_service_api_key)
        expect(Notifications::Client).to have_received(:new).with(*parameters)
        expect(VaNotify::Client).to have_received(:new).with(test_service_api_key, {})
      end
    end

    it 'correct api key passed to initialize when multiple services are defined' do
      test_service1_api_key = 'fa80e418-ff49-445c-a29b-92c04a181207-7aaec57c-2dc9-4d31-8f5c-7225fe79516a'
      test_base_url = 'https://fakishapi.com'
      parameters = test_service1_api_key, test_base_url
      with_settings(Settings.vanotify,
                    services: {
                      test_service1: {
                        api_key: test_service1_api_key
                      },
                      test_service2: {
                        api_key: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa-aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
                      }
                    },
                    client_url: test_base_url) do
        allow(Notifications::Client).to receive(:new).with(*parameters).and_return(notification_client)
        allow(VaNotify::Client).to receive(:new).with(test_service1_api_key, {}).and_return(va_notify_client)
        VaNotify::Service.new(test_service1_api_key)
        expect(Notifications::Client).to have_received(:new).with(*parameters)
        expect(VaNotify::Client).to have_received(:new).with(test_service1_api_key, {})
      end
    end

    it 'can receive callback_options' do
      test_base_url = 'https://fakishapi.com'
      callback_options = {
        callback_klass: 'TestTeam::TestClass',
        callback_metadata: 'optional_test_metadata'
      }
      with_settings(Settings.vanotify,
                    client_url: test_base_url) do
        allow(Notifications::Client).to receive(:new).with(test_api_key,
                                                           test_base_url).and_return(notification_client)
        service_object = VaNotify::Service.new(test_api_key, callback_options)
        expect(service_object.callback_options).to eq(callback_options)
      end
    end
  end

  describe '#send_email', test_service: false do
    subject { VaNotify::Service.new(test_api_key) }

    let(:notification_client) { double('Notifications::Client') }

    it 'calls notifications client' do
      VCR.use_cassette('va_notify/success_email') do
        allow(Notifications::Client).to receive(:new).and_return(notification_client)
        allow(notification_client).to receive(:send_email)
        allow(StatsD).to receive(:increment).with('api.vanotify.send_email.total')

        subject.send_email(send_email_parameters)
        expect(notification_client).to have_received(:send_email).with(send_email_parameters)
        expect(StatsD).to have_received(:increment).with('api.vanotify.send_email.total')
      end
    end

    context 'when :notification_creation flag is on' do
      it 'returns a response object' do
        VCR.use_cassette('va_notify/success_email') do
          allow(Flipper).to receive(:enabled?).with(:va_notify_notification_creation).and_return(true)

          response = subject.send_email(send_email_parameters)
          expect(response).to an_instance_of(Notifications::Client::ResponseNotification)
        end
      end

      context 'creates a notification record' do
        before do
          allow(Settings.vanotify).to receive(:services).and_return(
            { test_service: double('ServiceConfig', api_key: test_api_key) }
          )
          allow_any_instance_of(Notifications::Client).to receive(:secret_token).and_return(test_api_key_secret_token)
        end

        it 'without callback data' do
          VCR.use_cassette('va_notify/success_email') do
            allow(Flipper).to receive(:enabled?).with(:va_notify_notification_creation).and_return(true)

            subject.send_email(send_email_parameters)
            expect(VANotify::Notification.count).to eq(1)
            notification = VANotify::Notification.first
            expect(notification.source_location).to include('modules/va_notify/spec/lib/service_spec.rb')
            expect(notification.callback_klass).to be_nil
            expect(notification.callback_metadata).to be_nil
          end
        end

        it 'without nil passed in as callback data' do
          subject = VaNotify::Service.new(test_api_key, nil)

          VCR.use_cassette('va_notify/success_email') do
            allow(Flipper).to receive(:enabled?).with(:va_notify_notification_creation).and_return(true)

            subject.send_email(send_email_parameters)
            expect(VANotify::Notification.count).to eq(1)
            notification = VANotify::Notification.first
            expect(notification.source_location).to include('modules/va_notify/spec/lib/service_spec.rb')
            expect(notification.callback_klass).to be_nil
            expect(notification.callback_metadata).to be_nil
          end
        end

        it 'with string callback data' do
          VCR.use_cassette('va_notify/success_email') do
            subject = described_class.new(test_api_key,
                                          { 'callback_klass' => 'TestCallback',
                                            'callback_metadata' => 'optional_metadata' })
            allow(Flipper).to receive(:enabled?).with(:va_notify_notification_creation).and_return(true)
            allow(Rails.logger).to receive(:info)

            subject.send_email(send_email_parameters)
            expect(VANotify::Notification.count).to eq(1)
            notification = VANotify::Notification.first

            expect(Rails.logger).to have_received(:info).with(
              "VANotify notification: #{notification.id} saved",
              {
                callback_klass: 'TestCallback',
                callback_metadata: 'optional_metadata',
                source_location: anything,
                template_id: '1234'
              }
            )
            expect(notification.source_location).to include('modules/va_notify/spec/lib/service_spec.rb')
            expect(notification.callback_klass).to eq('TestCallback')
            expect(notification.callback_metadata).to eq('optional_metadata')
          end
        end

        it 'with callback data' do
          VCR.use_cassette('va_notify/success_email') do
            subject = described_class.new(test_api_key,
                                          { callback_klass: 'TestCallback', callback_metadata: 'optional_metadata' })
            allow(Flipper).to receive(:enabled?).with(:va_notify_notification_creation).and_return(true)
            allow(Rails.logger).to receive(:info)

            subject.send_email(send_email_parameters)
            expect(VANotify::Notification.count).to eq(1)
            notification = VANotify::Notification.first

            expect(Rails.logger).to have_received(:info).with(
              "VANotify notification: #{notification.id} saved",
              {
                callback_klass: 'TestCallback',
                callback_metadata: 'optional_metadata',
                source_location: anything,
                template_id: '1234'
              }
            )
            expect(notification.source_location).to include('modules/va_notify/spec/lib/service_spec.rb')
            expect(notification.callback_klass).to eq('TestCallback')
            expect(notification.callback_metadata).to eq('optional_metadata')
          end
        end
      end

      it 'logs an error if the notification cannot be saved' do
        VCR.use_cassette('va_notify/success_email') do
          allow(Settings.vanotify).to receive(:services).and_return(
            { test_service: double('ServiceConfig', api_key: test_api_key) }
          )
          allow_any_instance_of(Notifications::Client).to receive(:secret_token).and_return(test_api_key_secret_token)
          notification = VANotify::Notification.new
          notification.errors.add(:base, 'Some error occurred')
          allow(notification).to receive(:save).and_return(false)
          allow(VANotify::Notification).to receive(:new).and_return(notification)

          allow(Flipper).to receive(:enabled?).with(:va_notify_notification_creation).and_return(true)

          expect(Rails.logger).to receive(:error).with(
            'VANotify notification record failed to save',
            { error_messages: notification.errors.full_messages, template_id: '1234' }
          )

          subject.send_email(send_email_parameters)
        end
      end
    end
  end

  describe '#send_sms', test_service: false do
    subject { VaNotify::Service.new(test_api_key) }

    let(:notification_client) { double('Notifications::Client') }

    it 'calls notifications client' do
      allow(Notifications::Client).to receive(:new).and_return(notification_client)
      allow(notification_client).to receive(:send_sms).with(send_sms_parameters)
      allow(StatsD).to receive(:increment).with('api.vanotify.send_sms.total')

      subject.send_sms(send_sms_parameters)
      expect(notification_client).to have_received(:send_sms).with(send_sms_parameters)
      expect(StatsD).to have_received(:increment).with('api.vanotify.send_sms.total')
    end

    context 'when :notification_creation flag is on' do
      it 'returns a response object' do
        VCR.use_cassette('va_notify/success_sms') do
          allow(Flipper).to receive(:enabled?).with(:va_notify_notification_creation).and_return(true)

          response = subject.send_sms(send_sms_parameters)
          expect(response).to an_instance_of(Notifications::Client::ResponseNotification)
        end
      end

      it 'creates a notification record' do
        VCR.use_cassette('va_notify/success_sms') do
          allow(Flipper).to receive(:enabled?).with(:va_notify_notification_creation).and_return(true)
          allow(Settings.vanotify).to receive(:services).and_return(
            { test_service: double('ServiceConfig', api_key: test_api_key) }
          )
          allow_any_instance_of(Notifications::Client).to receive(:secret_token).and_return(test_api_key_secret_token)

          subject.send_sms(send_sms_parameters)
          expect(VANotify::Notification.count).to eq(1)
        end
      end

      it 'logs an error if the notification cannot be saved' do
        VCR.use_cassette('va_notify/success_sms') do
          notification = VANotify::Notification.new
          notification.errors.add(:base, 'Some error occurred')

          allow(notification).to receive(:save).and_return(false)
          allow(VANotify::Notification).to receive(:new).and_return(notification)
          allow(Settings.vanotify).to receive(:services).and_return(
            { test_service: double('ServiceConfig', api_key: test_api_key) }
          )
          allow_any_instance_of(Notifications::Client).to receive(:secret_token).and_return(test_api_key_secret_token)
          allow(Flipper).to receive(:enabled?).with(:va_notify_notification_creation).and_return(true)

          expect(Rails.logger).to receive(:error).with(
            'VANotify notification record failed to save',
            { error_messages: notification.errors.full_messages, template_id: '1234' }
          )

          subject.send_sms(send_sms_parameters)
        end
      end
    end
  end

  describe 'error handling', test_service: false do
    subject { VaNotify::Service.new(test_api_key) }

    context '400 errors' do
      it 'invalid template id' do
        allow(StatsD).to receive(:increment)

        VCR.use_cassette('va_notify/bad_request_invalid_template_id') do
          expect { subject.send_email(send_email_parameters) }.to raise_error do |e|
            expect(e).to be_a(VANotify::BadRequest)
            expect(e.status_code).to eq(400)
            expect(e.message).to include('ValidationError: template_id is not a valid UUID')
          end
        end

        expect(StatsD).to have_received(:increment).with('api.vanotify.send_email.fail',
                                                         { tags: ['error:CommonClientErrorsClientError',
                                                                  'status:400'] })
      end

      it 'missing personalization' do
        allow(StatsD).to receive(:increment)

        VCR.use_cassette('va_notify/bad_request_missing_personalization') do
          expect { subject.send_email(send_email_parameters) }.to raise_error do |e|
            expect(e).to be_a(VANotify::BadRequest)
            expect(e.status_code).to eq(400)
            expect(e.message).to include('Missing personalisation: baz')
          end
        end

        expect(StatsD).to have_received(:increment).with('api.vanotify.send_email.fail',
                                                         { tags: ['error:CommonClientErrorsClientError',
                                                                  'status:400'] })
      end

      it 'multiple errors' do
        allow(StatsD).to receive(:increment)

        VCR.use_cassette('va_notify/bad_request_multiple_errors') do
          expect { subject.send_email(send_email_parameters) }.to raise_error do |e|
            expect(e).to be_a(VANotify::BadRequest)
            expect(e.status_code).to eq(400)
            expect(e.message).to include('ValidationError: template_id is not a valid UUID')
            expect(e.message).to include('email_address Not a valid email address')
          end
        end

        expect(StatsD).to have_received(:increment).with('api.vanotify.send_email.fail',
                                                         { tags: ['error:CommonClientErrorsClientError',
                                                                  'status:400'] })
      end
    end

    it 'raises a 401 exception' do
      VCR.use_cassette('va_notify/auth_error_no_bearer') do
        expect { subject.send_email(send_email_parameters) }.to raise_error do |e|
          expect(e).to be_a(VANotify::Unauthorized)
          expect(e.status_code).to eq(401)
          expect(e.message).to include('AuthError: Unauthorized, authentication token must be provided')
        end
      end
    end

    it 'raises a 403 exception' do
      VCR.use_cassette('va_notify/auth_error_invalid_token') do
        expect { subject.send_email(send_email_parameters) }.to raise_error do |e|
          expect(e).to be_a(VANotify::Forbidden)
          expect(e.status_code).to eq(403)
          expect(e.message).to include('AuthError: Invalid token: signature, api token is not valid')
        end
      end
    end

    it 'raises a 404 exception' do
      VCR.use_cassette('va_notify/not_found') do
        expect { subject.send_email(send_email_parameters) }.to raise_error do |e|
          expect(e).to be_a(VANotify::NotFound)
          expect(e.status_code).to eq(404)
          expect(e.message).to include('The requested URL was not found on the server.')
        end
      end
    end

    it 'raises a 429 exception' do
      VCR.use_cassette('va_notify/too_many_requests') do
        expect { subject.send_email(send_email_parameters) }.to raise_error do |e|
          expect(e).to be_a(VANotify::RateLimitExceeded)
          expect(e.status_code).to eq(429)
          expect(e.message).to include('RateLimitError: Exceeded rate limit for key')
        end
      end
    end

    it 'raises a 500 exception' do
      VCR.use_cassette('va_notify/internal_server_error') do
        expect { subject.send_email(send_email_parameters) }.to raise_error do |e|
          expect(e).to be_a(VANotify::ServerError)
          expect(e.status_code).to eq(500)
          expect(e.message).to include('Internal server error')
        end
      end
    end

    it 'handles other errors' do
      VCR.use_cassette('va_notify/other_error') do
        expect { subject.send_email(send_email_parameters) }.to raise_error do |e|
          expect(e).to be_a(VANotify::Error)
          expect(e.status_code).to eq(501)
          expect(e.message).to include('Not Implemented')
        end
      end
    end
  end

  describe '#send_push' do
    subject { VaNotify::Service.new(test_api_key) }

    let(:push_client) { instance_double(VaNotify::Client) }
    let(:send_push_parameters) do
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
    let(:mock_push_response) do
      {
        result: 'success'
      }
    end

    before do
      allow(VaNotify::Client).to receive(:new).and_return(push_client)
      allow(push_client).to receive(:send_push).and_return(mock_push_response)
    end

    it 'initializes push client with correct parameters' do
      expect(VaNotify::Client).to receive(:new).with(test_api_key, {})
      subject.send_push(send_push_parameters)
    end

    it 'calls push client with correct parameters' do
      expect(push_client).to receive(:send_push).with(send_push_parameters)
      subject.send_push(send_push_parameters)
    end

    it 'returns the push client response' do
      response = subject.send_push(send_push_parameters)
      expect(response).to eq(mock_push_response)
    end

    it 'sets the template_id instance variable' do
      subject.send_push(send_push_parameters)
      expect(subject.template_id).to eq('fake-template-id-1234-5678-9012-34567890abcd')
    end

    it 'does not create a notification record' do
      expect { subject.send_push(send_push_parameters) }.not_to change(VANotify::Notification, :count)
    end

    context 'when push client raises an error' do
      let(:push_error) { StandardError.new('Push failed') }

      before do
        allow(push_client).to receive(:send_push).and_raise(push_error)
      end

      it 'handles the error and re-raises it' do
        expect { subject.send_push(send_push_parameters) }.to raise_error(StandardError, 'Push failed')
      end
    end
  end
end
