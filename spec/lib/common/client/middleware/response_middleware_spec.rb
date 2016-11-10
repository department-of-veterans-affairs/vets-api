# frozen_string_literal: true
require 'rails_helper'
require 'common/client/middleware/response/json_parser'
require 'common/client/middleware/response/raise_error'
require 'common/client/middleware/response/snakecase'
require 'common/client/errors'

describe 'Response Middleware' do
  let(:message_json) { attributes_for(:message).to_json }
  let(:five_o_o) { { "errorCode": 500, "message": 'Server Error' }.to_json }

  subject(:faraday_client) do
    Faraday.new do |conn|
      conn.response :snakecase
      conn.response :raise_error
      conn.response :json_parser

      conn.adapter :test do |stub|
        stub.get('ok') { [200, { 'Content-Type' => 'application/json' }, message_json] }
        stub.get('error') { [500, { 'Content-Type' => 'application/json' }, five_o_o] }
      end
    end
  end

  it 'parses json successfully' do
    client_response = subject.get('ok')
    expect(client_response.body).to be_a(Hash)
    expect(client_response.body.keys).to include(:id, :subject, :category, :body)
    expect(client_response.status).to eq(200)
  end

  it 'raises client response error' do
    expect { subject.get('error') }
      .to raise_error(Common::Client::Errors::ClientResponse)
  end
end
