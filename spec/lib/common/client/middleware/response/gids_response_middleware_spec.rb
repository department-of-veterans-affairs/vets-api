# frozen_string_literal: true

require 'rails_helper'
require 'common/client/middleware/response/json_parser'
require 'common/client/middleware/response/gids_errors'
require 'common/client/middleware/response/raise_custom_error'
require 'common/client/middleware/response/snakecase'
require 'common/client/errors'

describe Common::Client::Middleware::Response do
  subject(:gi_client) do
    Faraday.new do |conn|
      conn.response :snakecase
      conn.response :raise_custom_error, error_prefix: 'GI'
      conn.response :gids_errors
      conn.response :json_parser

      conn.adapter :test do |stub|
        stub.get('not-found') { [404, { 'Content-Type' => 'application/json' }, gids_error] }
      end
    end
  end

  let(:message_json) { attributes_for(:message).to_json }
  let(:gids_error) do
    '{"errors": [{"status": "404", "title": "Record not found", ' \
      '"detail": "The record identified by 31800132abc could not be found"}]}'
  end

  it 'raises client response error' do
    expect { gi_client.get('not-found') }
      .to raise_error do |error|
        expect(error).to be_a(Common::Exceptions::BackendServiceException)
        expect(error.errors.first[:title]).to eq('Record not found')
        expect(error.errors.first[:detail]).to eq('Record with the specified code was not found')
        expect(error.errors.first[:code]).to eq('GI404')
      end
  end
end
