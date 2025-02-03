# frozen_string_literal: true

require 'rails_helper'
require_relative '../../support/fixture_helper'

describe Eps::Middleware::EpsLogging do
  subject(:client) do
    Faraday.new do |conn|
      conn.use :eps_logging

      conn.adapter :test do |stub|
        stub.get(all_other_uris) { [status, { 'Content-Type' => 'text/plain', 'X-Vamf-Jwt' => sample_jwt }, '{}'] }
        stub.get(
          provider_service_uri
        ) { [status, { 'Content-Type' => 'text/plain', 'X-VAMF-JWT' => sample_jwt }, '{}'] }
      end
    end
  end

  let(:sample_jwt) { read_fixture_file('sample_jwt.response') }
  let(:all_other_uris) { 'https://fake.eps/whatever' }
  let(:provider_service_uri) { 'https://fake.eps/provider_service_uri' }
  let(:appt_uri) { 'https://fake.eps/appointments?patientId=1234567890V123456' }

  before do
    allow(Settings.va_mobile).to receive(:key_path).and_return(fixture_file_path('open_ssl_rsa_private.pem'))
    Timecop.freeze
  end

  after { Timecop.return }

  context 'with status successful' do
    let(:status) { 200 }

    it 'other requests with X-Vamf-Jwt log a success' do
      expect(Rails.logger).to receive(:info).with('Eps service call succeeded!',
                                                  jti: 'unknown jti',
                                                  status: 200,
                                                  duration: 0.0,
                                                  url: '(GET) https://fake.eps/whatever').and_call_original
      expect { client.get(all_other_uris, nil, { 'X-Vamf-Jwt' => sample_jwt }) }
        .to trigger_statsd_increment(
          'api.eps.response.total',
          tags: ['method:GET', 'url:/whatever', 'http_status:']
        )
    end

    it 'other requests with X-VAMF-JWT log a success' do
      expect(Rails.logger).to receive(:info).with('Eps service call succeeded!',
                                                  jti: 'unknown jti',
                                                  status: 200,
                                                  duration: 0.0,
                                                  url: '(GET) https://fake.eps/provider_service_uri').and_call_original
      expect { client.get(provider_service_uri, nil, { 'X-VAMF-JWT' => sample_jwt }) }
        .to trigger_statsd_increment(
          'api.eps.response.total',
          tags: ['method:GET', 'url:/provider_service_uri', 'http_status:']
        )
    end
  end

  context 'with status failed' do
    let(:status) { 500 }
    let(:sample_jwt) { '' }

    it 'other requests with X-Vamf-Jwt log a failure' do
      expect(Rails.logger).to receive(:warn).with('Eps service call failed!',
                                                  jti: 'unknown jti',
                                                  status: 500,
                                                  duration: 0.0,
                                                  url: '(GET) https://fake.eps/whatever',
                                                  vamf_msg: '{}').and_call_original
      client.get(all_other_uris, nil, { 'X-Vamf-Jwt' => sample_jwt })
    end

    it 'other requests with X-VAMF-JWT log a failure' do
      expect(Rails.logger).to receive(:warn).with('Eps service call failed!',
                                                  jti: 'unknown jti',
                                                  status: 500,
                                                  duration: 0.0,
                                                  url: '(GET) https://fake.eps/provider_service_uri',
                                                  vamf_msg: '{}').and_call_original
      client.get(provider_service_uri, nil, { 'X-VAMF-JWT' => sample_jwt })
    end
  end

  context 'with timeout' do
    it 'logs timeout error with hashed URI' do
      expected_log_tags = {
        duration: 0.0,
        jti: 'unknown jti',
        status: nil,
        url: '(POST) https://fake.eps/appointments?patientId=' \
             '441ab560b8fc574c6bf84d6c6105318b79455321a931ef701d39f4ff91894c64'
      }
      rails_log_msg = 'Eps service call failed - timeout'

      allow_any_instance_of(Faraday::Adapter).to receive(:call).and_raise(Faraday::TimeoutError)
      allow(Rails.logger).to receive(:warn).with(rails_log_msg, anything).and_call_original

      expect { client.post(appt_uri) }.to raise_error(Faraday::TimeoutError)
      expect(Rails.logger).to have_received(:warn).with(rails_log_msg, expected_log_tags).once
    end
  end
end
