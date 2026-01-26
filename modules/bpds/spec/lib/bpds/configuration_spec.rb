# frozen_string_literal: true

require 'rails_helper'
require 'bpds/configuration'

describe BPDS::Configuration do
  let(:base) { Common::Client::Configuration::REST }

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

  describe '#use_mocks?' do
    context 'when Settings.bpds.mock is true' do
      before { allow(Settings.bpds).to receive(:mock).and_return(true) }

      it 'returns true' do
        expect(BPDS::Configuration.instance).to be_use_mocks
      end
    end

    context 'when Settings.bpds.mock is false' do
      before { allow(Settings.bpds).to receive(:mock).and_return(false) }

      it 'returns false' do
        expect(BPDS::Configuration.instance).not_to be_use_mocks
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
      expected = base.base_request_headers # no additional headers

      headers = BPDS::Configuration.base_request_headers
      expect(headers).to match(hash_including(**expected))
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
