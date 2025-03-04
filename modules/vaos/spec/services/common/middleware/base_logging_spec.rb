# frozen_string_literal: true

require 'rails_helper'

# Test implementation of BaseLogging for specs
class TestLogging < Common::Middleware::BaseLogging
  private

  def config
    @config ||= OpenStruct.new(service_name: 'TEST_SERVICE')
  end

  def statsd_key_prefix
    'api.test.response'
  end
end

describe Common::Middleware::BaseLogging do
  subject(:client) do
    Faraday.new do |conn|
      conn.use TestLogging

      # Simulate HTTP responses to test the middleware behavior without making real network requests.
      conn.adapter :test do |stub|
        stub.get(test_uri) { [status, { 'Content-Type' => 'text/plain', 'X-Vamf-Jwt' => sample_jwt }, response_body] }
      end
    end
  end

  let(:sample_jwt) { 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJqdGkiOiJ0ZXN0LWp0aSJ9.mock' }
  let(:test_uri) { 'https://test.service/api' }
  let(:response_body) { '{}' }
  let(:status) { 200 }

  # Freeze time to ensure duration values in logs are consistent
  before { Timecop.freeze }
  after { Timecop.return }

  describe '#call' do
    context 'with successful response' do
      it 'logs success message with correct tags' do
        expect(Rails.logger).to receive(:info).with(
          'TEST_SERVICE service call succeeded!',
          hash_including(
            jti: 'test-jti',
            service_name: 'TEST_SERVICE',
            status: 200,
            duration: 0.0,
            url: '(GET) https://test.service/api'
          )
        )

        expect { client.get(test_uri, nil, { 'X-Vamf-Jwt' => sample_jwt }) }
          .to trigger_statsd_increment(
            'api.test.response.total',
            tags: ['method:GET', 'url:/api', 'http_status:']
          )
      end
    end

    context 'with 400 error response' do
      let(:status) { 400 }

      it 'logs warning without response body' do
        expect(Rails.logger).to receive(:warn).with(
          'TEST_SERVICE service call failed!',
          hash_including(
            jti: 'test-jti',
            service_name: 'TEST_SERVICE',
            status: 400,
            duration: 0.0,
            url: '(GET) https://test.service/api'
          )
        )

        client.get(test_uri, nil, { 'X-Vamf-Jwt' => sample_jwt })
      end
    end

    context 'with 500 error response' do
      let(:status) { 500 }
      let(:response_body) { '{"error": "server error"}' }

      it 'logs warning with response body' do
        expect(Rails.logger).to receive(:warn).with(
          'TEST_SERVICE service call failed!',
          hash_including(
            jti: 'test-jti',
            service_name: 'TEST_SERVICE',
            status: 500,
            duration: 0.0,
            url: '(GET) https://test.service/api',
            vamf_msg: '{"error": "server error"}'
          )
        )

        client.get(test_uri, nil, { 'X-Vamf-Jwt' => sample_jwt })
      end
    end

    context 'with timeout error' do
      it 'logs timeout error' do
        allow_any_instance_of(Faraday::Adapter).to receive(:call).and_raise(Faraday::TimeoutError)

        expect(Rails.logger).to receive(:warn).with(
          'TEST_SERVICE service call failed - timeout',
          hash_including(
            jti: 'test-jti',
            service_name: 'TEST_SERVICE',
            status: nil,
            duration: 0.0,
            url: '(GET) https://test.service/api'
          )
        )

        expect { client.get(test_uri, nil, { 'X-Vamf-Jwt' => sample_jwt }) }.to raise_error(Faraday::TimeoutError)
      end
    end

    context 'with invalid JWT' do
      let(:sample_jwt) { 'invalid-jwt' }

      it 'logs with unknown jti when JWT is invalid' do
        expect(Rails.logger).to receive(:info).with(
          'TEST_SERVICE service call succeeded!',
          hash_including(
            jti: 'unknown jti',
            service_name: 'TEST_SERVICE',
            status: 200,
            duration: 0.0,
            url: '(GET) https://test.service/api'
          )
        )

        client.get(test_uri, nil, { 'X-Vamf-Jwt' => sample_jwt })
      end
    end
  end

  describe 'contract requirements' do
    it 'requires subclasses to implement #config' do
      subclass = Class.new(described_class) do
        def statsd_key_prefix
          'test'
        end
      end

      instance = subclass.new(proc {})
      expect { instance.send(:config) }.to raise_error(NotImplementedError)
    end

    it 'requires subclasses to implement #statsd_key_prefix' do
      subclass = Class.new(described_class) do
        def config
          OpenStruct.new(service_name: 'test')
        end
      end

      instance = subclass.new(proc {})
      expect { instance.send(:statsd_key_prefix) }.to raise_error(NotImplementedError)
    end
  end
end
