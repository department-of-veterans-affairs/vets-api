# frozen_string_literal: true

require 'rails_helper'
require 'common/client/middleware/logging'

describe Common::Client::Middleware::Logging do
  subject(:client) do
    Faraday.new do |conn|
      conn.use :logging, type_key

      conn.adapter :test do |stub|
        stub.get('success') { [200, { 'Content-Type' => 'text/plain' }, response_data] }
        stub.post('success') { [200, { 'Content-Type' => 'text/plain' }, response_data] }
      end
    end
  end

  let(:type_key) { 'razzledaz' }
  let(:response_data) { 'muchado' }

  it 'creates a new personal information log record' do
    expect { client.get('success') }.to change(PersonalInformationLog, :count).by(1)
    expect(PersonalInformationLog.last.data.keys).to eq(%w[method url request_body response_body])
  end

  it 'correctly records (no) request body on a GET request' do
    client.get('success')
    expect(PersonalInformationLog.last.data['request_body']).to be_nil
  end

  it 'correctly records the request body on a non-GET request' do
    client.post('success', 'some_data')
    expect(PersonalInformationLog.last.data['request_body']).not_to be_nil
  end

  it 'correctly records the response body' do
    client.get('success')
    expect(PersonalInformationLog.last.data['response_body']).not_to be_nil
  end

  it 'correctly records the url' do
    client.get('success')
    expect(PersonalInformationLog.last.data['url']).to eq('http:/success')
  end

  it 'correctly records the request method' do
    client.get('success')
    expect(PersonalInformationLog.last.data['method']).to eq('get')
  end
end
