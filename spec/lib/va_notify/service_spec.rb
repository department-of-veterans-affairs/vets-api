# frozen_string_literal: true

require 'rails_helper'
require 'va_notify/service'

describe VaNotify::Service do
  before do
    @test_api_key = 'test-aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa-bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'
    @test_base_url = 'http://fakeapi.com'
    allow_any_instance_of(described_class).to receive(:api_key).and_return(@test_api_key)
    allow_any_instance_of(VaNotify::Configuration).to receive(:base_path).and_return(@test_base_url)
    allow_any_instance_of(VaNotify::Configuration).to receive(:api_key).and_return(@test_api_key)
  end

  send_email_parameters = {
    email_address: 'test@email.com',
    template_id: '1234',
    personalisation: {
      foo: 'bar'
    }
  }

  describe 'default' do
    let(:notification_client) {double('Notifications::Client')}
    
    it 'api key set when initialize without a service name' do
      parameters = @test_api_key, @test_base_url
      allow(Notifications::Client).to receive(:new).with(*parameters).and_return(notification_client)
      VaNotify::Service.new
      # expect(notification_client.base_url).to eq(@test_base_url)
      # expect(notification_client).to have_received(:new).with(@test_api_key, @test_base_url)
      expect(Notifications::Client).to have_received(:new).with(*parameters)
    end  
    
    xit 'api key based on service name passed to initialize' do
      # indicate Feature flag enabled
      Flipper.enable(:vanotify_service_enhancement)
    # VaNotify::Service.new('test')
    # assert somehow client was called with 'test' associated key
    end
  end

  describe '#send_email' do
    let(:notification_client) { double('Notifications::Client') }

    it 'calls notifications client' do
      allow(Notifications::Client).to receive(:new).and_return(notification_client)
      allow(notification_client).to receive(:send_email)

      subject.send_email(send_email_parameters)
      expect(notification_client).to have_received(:send_email).with(send_email_parameters)
    end
  end

  describe 'error handling' do
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
