# frozen_string_literal: true

require 'rails_helper'
require 'vye/dgib/configuration'
require 'vye/dgib/authentication_token_service'

describe Vye::DGIB::Configuration do
  describe '#base_path' do
    it 'has a base path' do
      expect(Vye::DGIB::Configuration.instance.base_path).to eq(Settings.dgi.vye.vets.url.to_s)
    end
  end

  describe '#service_name' do
    it 'has a service name' do
      expect(Vye::DGIB::Configuration.instance.service_name).to eq('VYE/DGIB')
    end
  end

  describe '#mock_enabled?' do
    # connection's memoized so this will avoid intermittent test failures w/Betamocks
    before do
      config = Vye::DGIB::Configuration.instance
      config.instance_variable_set(:@conn, nil)
    end

    context 'when Settings.dgi.vye.vets.mock is true' do
      before { Settings.dgi.vye.vets.mock = true }

      it 'returns true and the connection includes Betamocks' do
        config = Vye::DGIB::Configuration.instance
        expect(config.mock_enabled?).to be(true)
        expect(config.connection.builder.handlers.map(&:name)).to include('Betamocks::Middleware')
      end
    end

    context 'Settings.dgi.vye.vets.mock is false' do
      before { Settings.dgi.vye.vets.mock = false }

      it 'returns false and the connection does not include Betamocks' do
        config = Vye::DGIB::Configuration.instance
        expect(config.mock_enabled?).to be(false)
        expect(config.connection.builder.handlers.map(&:name)).not_to include('Betamocks::Middleware')
      end
    end
  end

  describe '#base_request_headers' do
    it 'includes the base headers' do
      headers = Vye::DGIB::Configuration.base_request_headers
      expect(headers['Accept']).to eq('application/json')
      expect(headers['Content-Type']).to eq('application/json')
      expect(headers['User-Agent']).to eq('Vets.gov Agent')
    end
  end

  describe '#connection' do
    let(:config) { Vye::DGIB::Configuration.instance }

    it 'creates a Faraday connection with the correct settings' do
      connection = config.connection
      expect(connection).to be_a(Faraday::Connection)
      expect(connection.ssl[:ca_file]).to eq(Settings.dgi.vye.jwt.public_ica11_rca2_key_path)

      middleware_names = connection.builder.handlers.map(&:name)
      expect(middleware_names).to include('Common::Client::Middleware::Response::Snakecase')
      expect(middleware_names).to include('Faraday::Response::RaiseError')
      expect(middleware_names).to include('Faraday::Request::Json')
    end

    it 'memoizes the connection' do
      connection1 = config.connection
      connection2 = config.connection
      expect(connection1).to be(connection2)
    end
  end
end
