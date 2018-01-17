# frozen_string_literal: true

require 'rails_helper'
require 'common/client/middleware/response/json_parser'
require 'common/client/middleware/response/caseflow_errors'
require 'common/client/middleware/response/raise_error'
require 'common/client/middleware/response/snakecase'
require 'common/client/errors'

describe 'Appeals Response Middleware' do
  let(:message_json) { attributes_for(:message).to_json }
  let(:caseflow_error) do
    '{"errors": [{"status": "404", "title": "Veteran not found", ' \
    '"detail": "A veteran with that SSN was not found in our systems."}]}'
  end

  subject(:appeals_client) do
    Faraday.new do |conn|
      conn.response :snakecase
      conn.response :raise_error, error_prefix: 'AppealsStatus'
      conn.response :caseflow_errors
      conn.response :json_parser

      conn.adapter :test do |stub|
        stub.get('not-found') { [404, { 'Content-Type' => 'application/json' }, caseflow_error] }
      end
    end
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
