# frozen_string_literal: true
require 'rails_helper'
require 'facilities/gis_middleware'
require 'facilities/errors'

describe 'GIS Middleware' do
  let(:valid_json) { { 'features' => [{ 'foo' => 'bar' }, { 'key' => 'value' }] }.to_json }
  let(:error_json) { { 'error' => { 'code' => 400, 'message' => 'Invalid request' } }.to_json }
  let(:non_json) { 'I am not json' }

  subject(:faraday_client) do
    Faraday.new do |conn|
      conn.use Facilities::Middleware::GISJson

      conn.adapter :test do |stub|
        stub.get('ok') { [200, { 'Content-Type' => 'application/json' }, valid_json] }
        stub.get('error') { [200, { 'Content-Type' => 'application/json' }, error_json] }
        stub.get('non-json') { [200, { 'Content-Type' => 'application/json' }, non_json] }
        stub.get('error-code') { [500, { 'Content-Type' => 'application/json' }, non_json] }
      end
    end
  end

  it 'parses json' do
    client_response = subject.get('ok')
    expect(client_response.body).to be_a(Hash)
    expect(client_response.body.keys).to include('features')
  end

  it 'raises service error on unparseable json' do
    expect { subject.get('non-json') }
      .to raise_error(Facilities::Errors::ServiceError)
  end

  it 'raises service error on error json response' do
    expect { subject.get('error') }
      .to raise_error(Facilities::Errors::ServiceError)
  end

  it 'raises service error on error code response' do
    expect { subject.get('error-code') }
      .to raise_error(Facilities::Errors::ServiceError)
  end
end
