# frozen_string_literal: true

require 'rails_helper'

describe Eps::BaseService do
  user_icn = '123456789V123456'

  let(:user) { double('User', account_uuid: '1234', icn: user_icn) }
  let(:service) { described_class.new(user) }
  let(:config) { instance_double(Eps::Configuration, api_url: 'https://api.wellhive.com', base_path: 'api/v1') }
  let(:request_id) { '123456-abcdef' }
  let(:memory_store) { ActiveSupport::Cache::MemoryStore.new }

  before do
    allow(service).to receive(:config).and_return(config)
    RequestStore.store['request_id'] = request_id
    allow(Rails).to receive(:cache).and_return(memory_store)
    Rails.cache.clear
  end

  describe '#config' do
    it 'returns the Eps::Configuration instance' do
      allow(service).to receive(:config).and_call_original
      expect(service.config).to be_instance_of(Eps::Configuration)
    end
  end

  describe '#patient_id' do
    it 'returns the user ICN' do
      expect(service.send(:patient_id)).to eq(user_icn)
    end

    it 'memoizes the ICN' do
      expect(user).to receive(:icn).once.and_return(user_icn)
      2.times { service.send(:patient_id) }
    end
  end

  describe '#request_headers_with_correlation_id' do
    context 'when mocks are enabled' do
      before do
        allow(config).to receive(:mock_enabled?).and_return(true)
      end

      it 'returns empty hash' do
        expect(service.send(:request_headers_with_correlation_id)).to eq({})
      end
    end

    context 'when mocks are disabled' do
      before do
        allow(config).to receive(:mock_enabled?).and_return(false)
        # Mock the token authentication method to avoid actual API calls
        allow(service).to receive(:headers_with_correlation_id).and_return({
                                                                             'Authorization' => 'Bearer test-token',
                                                                             'Content-Type' => 'application/json',
                                                                             'X-Request-ID' => 'test-correlation-id',
                                                                             'X-Parent-Request-ID' => request_id
                                                                           })
      end

      it 'delegates to headers_with_correlation_id method' do
        expect(service).to receive(:headers_with_correlation_id)
        service.send(:request_headers_with_correlation_id)
      end

      it 'returns the headers from token authentication' do
        headers = service.send(:request_headers_with_correlation_id)
        expect(headers).to eq({
                                'Authorization' => 'Bearer test-token',
                                'Content-Type' => 'application/json',
                                'X-Request-ID' => 'test-correlation-id',
                                'X-Parent-Request-ID' => request_id
                              })
      end
    end
  end

  describe 'sanitization helpers' do
    before do
      allow(VAOS::Anonymizers).to receive(:anonymize_icns) do |text|
        text.to_s.gsub(/\b\d{9}V\d{6}\b/, '[REDACTED-ICN]')
      end
      allow(VAOS::Anonymizers).to receive(:anonymize_uri_icn) do |uri|
        str = uri.is_a?(String) ? uri : uri.to_s
        URI(str.gsub(/\b\d{9}V\d{6}\b/, '[REDACTED-ICN]'))
      end
    end

    describe '#sanitize_url' do
      it 'anonymizes ICNs in URLs' do
        url = 'https://api.example.com/patients/123456789V123456/appointments'
        sanitized = service.send(:sanitize_url, url)
        expect(sanitized).not_to include('123456789V123456')
      end

      it 'returns [Invalid URL] for malformed URLs' do
        sanitized = service.send(:sanitize_url, ':::bad::url')
        expect(sanitized).to eq('[Invalid URL]')
      end

      it 'returns nil for nil' do
        expect(service.send(:sanitize_url, nil)).to be_nil
      end
    end

    describe '#sanitize_response_body' do
      it 'anonymizes ICNs in body' do
        body = 'Patient ICN 123456789V123456 had an error'
        sanitized = service.send(:sanitize_response_body, body)
        expect(sanitized).not_to include('123456789V123456')
      end

      it 'redacts SSNs' do
        body = 'SSN 123-45-6789 present'
        sanitized = service.send(:sanitize_response_body, body)
        expect(sanitized).to include('[REDACTED-SSN]')
        expect(sanitized).not_to include('123-45-6789')
      end

      it 'redacts 9 digit numbers' do
        body = 'Record 123456789 found'
        sanitized = service.send(:sanitize_response_body, body)
        expect(sanitized).to include('[REDACTED-NUMBER]')
        expect(sanitized).not_to include('123456789')
      end

      it 'redacts emails' do
        body = 'Contact test.user@example.com for help'
        sanitized = service.send(:sanitize_response_body, body)
        expect(sanitized).to include('[REDACTED-EMAIL]')
        expect(sanitized).not_to include('test.user@example.com')
      end

      it 'returns nil for nil' do
        expect(service.send(:sanitize_response_body, nil)).to be_nil
      end
    end
  end
end
