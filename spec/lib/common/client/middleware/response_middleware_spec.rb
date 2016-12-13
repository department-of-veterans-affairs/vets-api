# frozen_string_literal: true
require 'rails_helper'
require 'common/client/middleware/response/json_parser'
require 'common/client/middleware/response/mhv_errors'
require 'common/client/middleware/response/raise_error'
require 'common/client/middleware/response/snakecase'
require 'common/client/errors'

describe 'Response Middleware' do
  let(:message_json) { attributes_for(:message).to_json }
  let(:four_o_four) { { "errorCode": 400, "message": 'Record Not Found', "developerMessage": 'blah' }.to_json }
  let(:i18n_type_error) { { "errorCode": 139, "message": 'server response', "developerMessage": 'blah' }.to_json }

  subject(:faraday_client) do
    Faraday.new do |conn|
      conn.response :snakecase
      conn.response :raise_error, error_prefix: 'RX'
      conn.response :mhv_errors
      conn.response :json_parser

      conn.adapter :test do |stub|
        stub.get('ok') { [200, { 'Content-Type' => 'application/json' }, message_json] }
        stub.get('not-found') { [404, { 'Content-Type' => 'application/json' }, four_o_four] }
        stub.get('refill-fail') { [400, { 'Content-Type' => 'application/json' }, i18n_type_error] }
      end
    end
  end

  it 'parses json successfully' do
    client_response = faraday_client.get('ok')
    expect(client_response.body).to be_a(Hash)
    expect(client_response.body.keys).to include(:id, :subject, :category, :body)
    expect(client_response.status).to eq(200)
  end

  it 'raises client response error' do
    message = 'BackendServiceException: {:status=>404, :detail=>"Record Not Found", :code=>"VA900", :source=>"blah"}'
    expect { faraday_client.get('not-found') }
      .to raise_error do |error|
        expect(error).to be_a(Common::Exceptions::BackendServiceException)
        expect(error.message)
          .to eq(message)
        expect(error.errors.first[:detail])
          .to eq('Record Not Found')
      end
  end

  it 'can override a response error using i18n' do
    message = 'BackendServiceException: {:status=>400, :detail=>"server response", :code=>"RX139", :source=>"blah"}'
    expect { faraday_client.get('refill-fail') }
      .to raise_error do |error|
        expect(error).to be_a(Common::Exceptions::BackendServiceException)
        expect(error.message)
          .to eq(message)
        expect(error.errors.first[:detail])
          .to eq('Prescription is not refillable')
      end
  end
end
