# frozen_string_literal: true

require 'rails_helper'
require 'bpds/configuration'
require 'bpds/jwt_encoder'

describe BPDS::Configuration do
  describe '#base_path' do
    it 'has a base path' do
      expect(BPDS::Configuration.instance.base_path).to eq(Settings.bpds.url)
    end
  end

  describe '#service_name' do
    it 'has a service name' do
      expect(BPDS::Configuration.instance.service_name).to eq('BPDS::Service')
    end
  end

  describe '#mock_enabled?' do
    context 'when Settings.bpds.mock is true' do
      before { allow(Settings.bpds).to receive(:mock).and_return(true) }

      it 'returns true' do
        expect(BPDS::Configuration.instance).to be_mock_enabled
      end
    end

    context 'when Settings.bpds.mock is false' do
      before { allow(Settings.bpds).to receive(:mock).and_return(false) }

      it 'returns false' do
        expect(BPDS::Configuration.instance).not_to be_mock_enabled
      end
    end
  end

  describe '#breakers_error_threshold' do
    it 'returns the correct error threshold' do
      expect(BPDS::Configuration.instance.breakers_error_threshold).to eq(80)
    end
  end

  describe '.base_request_headers' do
    it 'includes the Authorization header' do
      # rubocop:disable RSpec/MessageChain
      allow(BPDS::JwtEncoder).to receive_message_chain(:new, :get_token).and_return('test_token')
      # rubocop:enable RSpec/MessageChain
      headers = BPDS::Configuration.base_request_headers
      expect(headers['Authorization']).to eq('Bearer test_token')
    end
  end

  describe '#connection' do
    it 'creates a Faraday connection' do
      config = BPDS::Configuration.instance
      connection = config.connection
      expect(connection).to be_a(Faraday::Connection)
    end
  end
end
