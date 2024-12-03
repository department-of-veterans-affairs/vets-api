# frozen_string_literal: true

require 'rails_helper'
require 'carma/client/mule_soft_auth_token_client'

describe CARMA::Client::MuleSoftAuthTokenClient do
  let(:client) { described_class.new }

  let(:config) { double('config') }
  let(:timeout) { 60 }
  let(:settings) do
    OpenStruct.new(
      token_url: 'my/token/url',
      client_id: 'id',
      client_secret: 'secret',
      auth_token_path: 'auth/token/path',
      timeout:
    )
  end

  before do
    allow(client).to receive(:config).and_return(config)
    allow(config).to receive_messages(timeout:, settings:)
  end

  describe '#new_bearer_token' do
    subject { client.new_bearer_token }

    let(:token_params) do
      URI.encode_www_form({
                            grant_type: CARMA::Client::MuleSoftAuthTokenClient::GRANT_TYPE,
                            scope: CARMA::Client::MuleSoftAuthTokenClient::SCOPE
                          })
    end

    let(:basic_auth) do
      Base64.urlsafe_encode64("#{config.settings.client_id}:#{config.settings.client_secret}")
    end

    let(:token_headers) do
      {
        'Authorization' => "Basic #{basic_auth}",
        'Content-Type' => 'application/x-www-form-urlencoded'
      }
    end

    let(:options) { { timeout: } }

    let(:token) { 'my-token' }
    let(:response_body) do
      "{\"token_type\":\"Bearer\",\"expires_in\":3600,\"access_token\":\"#{token}\",\"scope\":\"DTCWriteResource\"}"
    end

    let(:mock_token_response) { Faraday::Response.new(response_body:, status: 200) }

    context 'successfully gets token' do
      it 'calls perform with expected params' do
        expect(client).to receive(:perform)
          .with(
            :post,
            config.settings.auth_token_path,
            token_params, token_headers, options
          )
          .and_return(mock_token_response)

        expect(subject).to eq token
      end
    end

    context 'error getting token' do
      let(:mock_error_token_response) { Faraday::Response.new(response_body: { sad: true }, status: 400) }

      it 'raises error' do
        expect(client).to receive(:perform)
          .with(:post, config.settings.auth_token_path, token_params, token_headers, options)
          .and_return(mock_error_token_response)

        expect do
          subject
        end.to raise_error(CARMA::Client::MuleSoftAuthTokenClient::GetAuthTokenError,
                           "Response: #{mock_error_token_response}")
      end
    end
  end
end
