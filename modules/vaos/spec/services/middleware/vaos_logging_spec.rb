# frozen_string_literal: true

require 'rails_helper'
require_relative '../../support/fixture_helper'

describe VAOS::Middleware::VaosLogging do
  subject(:client) do
    Faraday.new do |conn|
      conn.use :vaos_logging, service_name

      conn.adapter :test do |stub|
        stub.get(all_other_uris) { [status, { 'Content-Type' => 'text/plain', 'X-Vamf-Jwt' => sample_jwr }, '{}'] }
        stub.post(user_service_uri) { [status, { 'Content-Type' => 'text/plain' }, sample_jwt] }
      end
    end
  end

  let(:service_name) { 'jalepeno' }
  let(:sample_jwt) { read_fixture_file('sample_jwt.response') }
  let(:all_other_uris) { '' }
  let(:user_service_uri) { 'https://veteran.apps.va.gov/users/v2/session?processRules=true' }

  before { Settings.va_mobile.key_path = fixture_file_path('open_ssl_rsa_private.pem') }

  context 'with status successful' do
    let(:status) { 200 }

    it 'user service call logs a success' do
      client.post(user_service_uri)
    end

    it 'other requests logs a success' do
      client.get(all_other_uris)
    end
  end

  context 'with status failed' do
    let(:status) { 500 }
    let(:sample_jwt) { '' }

    it 'user service calls logs a failure' do
      client.post(user_service_uri)
    end

    it 'other requests logs a failure' do
      client.get(all_other_uris)
    end
  end
end
