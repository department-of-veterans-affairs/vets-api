# frozen_string_literal: true

require 'rails_helper'

describe Mobile::V0::LighthouseHealth::Configuration do
  subject(:config) { described_class.instance }

  describe '#access_token_connection' do
    it 'sets Content-Type header to application/x-www-form-urlencoded' do
      # This header is required for OAuth token requests.
      # net-http v0.7.0+ removed automatic Content-Type defaults for POST requests,
      # so we must explicitly set this header to prevent 400 errors from the OAuth server.
      connection = config.access_token_connection

      expect(connection.headers['Content-Type']).to eq('application/x-www-form-urlencoded')
    end

    it 'includes RaiseError middleware for error handling' do
      connection = config.access_token_connection

      expect(connection.builder.handlers).to include(Faraday::Response::RaiseError)
    end

    it 'includes breakers middleware for circuit breaking' do
      connection = config.access_token_connection

      # Breakers middleware is registered as a symbol
      handler_names = connection.builder.handlers.map do |h|
        h.name
      rescue
        h.to_s
      end
      expect(handler_names.join).to include('breakers').or include('Breakers')
    end

    it 'includes JSON response middleware' do
      connection = config.access_token_connection

      expect(connection.builder.handlers).to include(Faraday::Response::Json)
    end
  end

  describe '#connection' do
    it 'does not require Content-Type header (used for GET requests with Bearer token)' do
      connection = config.connection

      # The main connection is used for API requests with Authorization header,
      # not for token requests, so Content-Type is not required
      expect(connection.headers['Content-Type']).to be_nil
    end
  end

  describe '#service_name' do
    it 'returns the correct service name for breakers' do
      expect(config.service_name).to eq('MobileLighthouseHealth')
    end
  end
end
