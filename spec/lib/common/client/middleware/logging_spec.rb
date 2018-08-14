# frozen_string_literal: true

require 'rails_helper'
require 'common/client/middleware/logging'

describe 'Logging Middleware' do
  let(:type_key) { 'razzledaz' }
  let(:response_data) { 'muchado' }

  subject(:client) do
    Faraday.new do |conn|
      conn.response :logging, type_key

      conn.adapter :test do |stub|
        stub.get('success') { |200, { 'Content-Type' => 'text/plain' }, response_data] }
      end
    end
  end

  it 'creates a new personal information log record' do

  end

  it 'correctly records (no) request body on a GET request' do

  end

  it 'correctly records the request body on a non-GET request' do

  end

  it 'correctly records the response body' do

  end

  it 'correctly records the url' do

  end

  it 'correctly records the request method' do

  end

  it 'raises client response error' do
    message = 'BackendServiceException: {:status=>404, :detail=>"Veteran not found", ' \
              ':code=>"APPEALSSTATUS404", :source=>"A veteran with that SSN was not found in our systems."}'
    expect { appeals_client.get('not-found') }
      .to raise_error do |error|
        expect(error).to be_a(Common::Exceptions::BackendServiceException)
        expect(error.message).to eq(message)
        expect(error.errors.first[:detail]).to eq('Appeals data for a veteran with that SSN was not found')
        expect(error.errors.first[:code]).to eq('APPEALSSTATUS404')
      end
  end
end
