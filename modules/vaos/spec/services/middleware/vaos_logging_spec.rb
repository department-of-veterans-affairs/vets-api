# frozen_string_literal: true

require 'rails_helper'
require_relative '../../support/fixture_helper'

describe VAOS::Middleware::VAOSLogging do
  subject(:client) do
    Faraday.new do |conn|
      conn.use :vaos_logging

      conn.adapter :test do |stub|
        stub.get(all_other_uris) { [status, { 'Content-Type' => 'text/plain', 'X-Vamf-Jwt' => sample_jwt }, '{}'] }
        stub.get(
          user_service_refresh_uri
        ) { [status, { 'Content-Type' => 'text/plain', 'X-VAMF-JWT' => sample_jwt }, '{}'] }
        stub.post(user_service_uri) { [status, { 'Content-Type' => 'text/plain' }, sample_jwt] }
      end
    end
  end

  let(:sample_jwt) { read_fixture_file('sample_jwt.response') }
  let(:all_other_uris) { 'https://veteran.apps.va.gov/whatever' }
  let(:user_service_refresh_uri) { 'https://veteran.apps.va.gov/user_service_refresh_uri' }
  let(:user_service_uri) { 'https://veteran.apps.va.gov/users/v2/session?processRules=true' }

  before do
    allow(Settings.va_mobile).to receive(:key_path).and_return(fixture_file_path('open_ssl_rsa_private.pem'))
    Timecop.freeze
  end

  after { Timecop.return }

  context 'with status successful' do
    let(:status) { 200 }

    it 'user service call logs a success and increments total' do
      expect(Rails.logger).to receive(:info).with('VAOS service call succeeded!',
                                                  jti: 'ebfc95ef5f3a41a7b15e432fe47e9864',
                                                  status: 200,
                                                  duration: 0.0,
                                                  url: '(POST) https://veteran.apps.va.gov/users/v2/session?processRules=true').and_call_original
      expect { client.post(user_service_uri) }
        .to trigger_statsd_increment(
          'api.vaos.va_mobile.response.total',
          tags: ['method:POST', 'url:/users/v2/session', 'http_status:']
        )
    end

    it 'other requests with X-Vamf-Jwt log a success' do
      expect(Rails.logger).to receive(:info).with('VAOS service call succeeded!',
                                                  jti: 'ebfc95ef5f3a41a7b15e432fe47e9864',
                                                  status: 200,
                                                  duration: 0.0,
                                                  url: '(GET) https://veteran.apps.va.gov/whatever').and_call_original
      expect { client.get(all_other_uris, nil, { 'X-Vamf-Jwt' => sample_jwt }) }
        .to trigger_statsd_increment(
          'api.vaos.va_mobile.response.total',
          tags: ['method:GET', 'url:/whatever', 'http_status:']
        )
    end

    it 'other requests with X-VAMF-JWT log a success' do
      expect(Rails.logger).to receive(:info).with('VAOS service call succeeded!',
                                                  jti: 'ebfc95ef5f3a41a7b15e432fe47e9864',
                                                  status: 200,
                                                  duration: 0.0,
                                                  url: '(GET) https://veteran.apps.va.gov/user_service_refresh_uri').and_call_original
      expect { client.get(user_service_refresh_uri, nil, { 'X-VAMF-JWT' => sample_jwt }) }
        .to trigger_statsd_increment(
          'api.vaos.va_mobile.response.total',
          tags: ['method:GET', 'url:/user_service_refresh_uri', 'http_status:']
        )
    end
  end

  context 'with status failed' do
    let(:status) { 500 }
    let(:sample_jwt) { '' }

    it 'user service calls logs a failure' do
      expect(Rails.logger).to receive(:warn).with('VAOS service call failed!',
                                                  jti: 'unknown jti',
                                                  status: 500,
                                                  duration: 0.0,
                                                  url: '(POST) https://veteran.apps.va.gov/users/v2/session?processRules=true',
                                                  vamf_msg: '').and_call_original
      client.post(user_service_uri)
    end

    it 'other requests with X-Vamf-Jwt log a failure' do
      expect(Rails.logger).to receive(:warn).with('VAOS service call failed!',
                                                  jti: 'unknown jti',
                                                  status: 500,
                                                  duration: 0.0,
                                                  url: '(GET) https://veteran.apps.va.gov/whatever',
                                                  vamf_msg: '{}').and_call_original
      client.get(all_other_uris, nil, { 'X-Vamf-Jwt' => sample_jwt })
    end

    it 'other requests with X-VAMF-JWT log a failure' do
      expect(Rails.logger).to receive(:warn).with('VAOS service call failed!',
                                                  jti: 'unknown jti',
                                                  status: 500,
                                                  duration: 0.0,
                                                  url: '(GET) https://veteran.apps.va.gov/user_service_refresh_uri',
                                                  vamf_msg: '{}').and_call_original
      client.get(user_service_refresh_uri, nil, { 'X-VAMF-JWT' => sample_jwt })
    end
  end
end
