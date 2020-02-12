# frozen_string_literal: true

require 'rails_helper'
require_relative '../../support/fixture_helper'

describe VAOS::Middleware::VaosLogging do
  subject(:client) do
    Faraday.new do |conn|
      conn.use :vaos_logging, service_name

      conn.adapter :test do |stub|
        stub.get('success') { [200, { 'Content-Type' => 'text/plain' }, response_data] }
        stub.post(user_service_uri) { [200, { 'Content-Type' => 'text/plain' }, response_data] }
      end
    end
  end

  let(:service_name) { 'jalepeno' }
  let(:response_data) { fixture_file_path('sample_jwt.response') }
  let(:user_service_uri) { 'https://veteran.apps.va.gov/users/v2/session?processRules=true' }

  before { Settings.va_mobile.key_path = fixture_file_path('open_ssl_rsa_private.pem') }

  it 'is a temp test to check for failure' do
    client.post(user_service_uri)
    #   expect('not nil').to be_nil
  end

  # test for exception during call
end
