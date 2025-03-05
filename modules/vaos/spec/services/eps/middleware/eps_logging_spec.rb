# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../support/fixture_helper'

describe Eps::Middleware::EpsLogging do
  subject(:client) do
    Faraday.new do |conn|
      conn.use :eps_logging

      conn.adapter :test do |stub|
        stub.get(test_uri) { [status, { 'Content-Type' => 'text/plain', 'X-Vamf-Jwt' => sample_jwt }, '{}'] }
      end
    end
  end

  let(:sample_jwt) { read_fixture_file('sample_jwt.response') }
  let(:test_uri) { 'https://fake.eps/api' }
  let(:status) { 200 }

  it 'uses correct configuration' do
    expect(Eps::Configuration.instance).to receive(:service_name).at_least(:once).and_return('EPS')
    client.get(test_uri, nil, { 'X-Vamf-Jwt' => sample_jwt })
  end

  it 'uses correct statsd prefix' do
    expect { client.get(test_uri, nil, { 'X-Vamf-Jwt' => sample_jwt }) }
      .to trigger_statsd_increment(
        'api.eps.response.total',
        tags: ['method:GET', 'url:/api', 'http_status:']
      )
  end
end
