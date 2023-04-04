# frozen_string_literal: true

require 'rails_helper'
require 'va_notify/service'

describe VaNotify::Service do
  before(:example, test_service: false) do
    test_base_url = 'http://fakeapi.com'
    allow_any_instance_of(VaNotify::Configuration).to receive(:base_path).and_return(test_base_url)
  end

  let(:test_api_key) { 'test-aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa-bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb' }
  let(:send_email_parameters) do
    {
      email_address: 'test@email.com',
      template_id: '1234',
      personalisation: {
        foo: 'bar'
      }
    }
  end
  let(:send_sms_parameters) do
    {
      phone_number: '+19876543210',
      template_id: '1234',
      sms_sender_id: '9876',
      personalisation: {
        foo: 'bar'
      }
    }
  end

  describe 'service initialization', test_service: true do
    let(:notification_client) { double('Notifications::Client') }

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
        VaNotify::Service.new(test_service_api_key)
        expect(Notifications::Client).to have_received(:new).with(*parameters)
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
        VaNotify::Service.new(test_service1_api_key)
        expect(Notifications::Client).to have_received(:new).with(*parameters)
      end
    end
  end

  describe '#send_email', test_service: false do
    subject { VaNotify::Service.new(test_api_key) }

    let(:notification_client) { double('Notifications::Client') }

    it 'calls notifications client' do
      allow(Notifications::Client).to receive(:new).and_return(notification_client)
      allow(notification_client).to receive(:send_email)

      subject.send_email(send_email_parameters)
      expect(notification_client).to have_received(:send_email).with(send_email_parameters)
    end
  end

  describe '#send_sms', test_service: false do
    subject { VaNotify::Service.new(test_api_key) }

    let(:notification_client) { double('Notifications::Client') }

    it 'calls notifications client' do
      allow(Notifications::Client).to receive(:new).and_return(notification_client)
      allow(notification_client).to receive(:send_sms)

      subject.send_sms(send_sms_parameters)
      expect(notification_client).to have_received(:send_sms).with(send_sms_parameters)
    end
  end

  describe 'error handling', test_service: false do
    subject { VaNotify::Service.new(test_api_key) }

    it 'raises a 400 exception' do
      VCR.use_cassette('va_notify/bad_request') do
        expect { subject.send_email(send_email_parameters) }.to raise_error do |e|
          expect(e).to be_a(Common::Exceptions::BackendServiceException)
          expect(e.status_code).to eq(400)
          expect(e.errors.first.code).to eq('VANOTIFY_400')
        end
      end
    end

    it 'raises a 403 exception' do
      VCR.use_cassette('va_notify/auth_error') do
        expect { subject.send_email(send_email_parameters) }.to raise_error do |e|
          expect(e).to be_a(Common::Exceptions::BackendServiceException)
          expect(e.status_code).to eq(403)
          expect(e.errors.first.code).to eq('VANOTIFY_403')
        end
      end
    end

    it 'raises a 404 exception' do
      VCR.use_cassette('va_notify/not_found') do
        expect { subject.send_email(send_email_parameters) }.to raise_error do |e|
          expect(e).to be_a(Common::Exceptions::BackendServiceException)
          expect(e.status_code).to eq(404)
          expect(e.errors.first.code).to eq('VANOTIFY_404')
        end
      end
    end

    it 'raises a 429 exception' do
      VCR.use_cassette('va_notify/too_many_requests') do
        expect { subject.send_email(send_email_parameters) }.to raise_error do |e|
          expect(e).to be_a(Common::Exceptions::BackendServiceException)
          expect(e.status_code).to eq(429)
          expect(e.errors.first.code).to eq('VANOTIFY_429')
        end
      end
    end

    it 'raises a 500 exception' do
      VCR.use_cassette('va_notify/internal_server_error') do
        expect { subject.send_email(send_email_parameters) }.to raise_error do |e|
          expect(e).to be_a(Common::Exceptions::BackendServiceException)
          expect(e.status_code).to eq(500)
          expect(e.errors.first.code).to eq('VANOTIFY_500')
        end
      end
    end
  end
end
