# frozen_string_literal: true

require 'rails_helper'
require 'common/client/configuration/rest'
require 'lighthouse/benefits_intake/configuration'

RSpec.describe BenefitsIntake::Configuration do
  let(:base) { Common::Client::Configuration::REST }
  let(:config) { BenefitsIntake::Configuration.send(:new) }
  let(:settings) do
    OpenStruct.new({
                     host: 'https://sandbox-api.va.gov',
                     path: '/services/vba_documents',
                     version: 'v1',
                     use_mocks: false,
                     api_key: 'some-long-hash-api-key'
                   })
  end

  before do
    allow(Settings.lighthouse).to receive(:benefits_intake).and_return(settings)
  end

  context 'valid settings' do
    it 'returns settings' do
      expect(config.intake_settings).to eq(settings)
    end

    it 'has correct api_key' do
      expect(config.intake_settings.api_key).to eq(settings.api_key)
    end

    it 'returns service_path' do
      valid_path = 'https://sandbox-api.va.gov/services/vba_documents/v1'
      expect(config.service_path).to eq(valid_path)
    end

    it 'returns use_mocks' do
      expect(config.use_mocks?).to eq(settings.use_mocks)
    end
  end

  context 'expected constants' do
    it 'returns service_name' do
      expect(config.service_name).to eq('BenefitsIntake')
    end

    it 'returns breakers_error_threshold' do
      expect(config.breakers_error_threshold).to eq(80)
    end
  end

  describe '#base_request_headers' do
    it 'returns expected headers' do
      headers = config.base_request_headers
      expected = base.base_request_headers.merge({ 'apikey' => settings.api_key })
      expect(headers).to eq(expected)
    end

    it 'errors if missing api_key' do
      allow(Settings.lighthouse.benefits_intake).to receive(:api_key).and_return(nil)
      expect { config.base_request_headers }.to raise_error StandardError, /^No api_key set.+/
    end
  end

  describe '#connection' do
    let(:faraday) { double('faraday') }

    before do
      allow(Faraday).to receive(:new).and_yield(faraday)

      allow(config).to receive_messages(service_path: 'service_path', base_request_headers: 'base_request_headers',
                                        request_options: 'request_options', use_mocks?: true)
    end

    it 'returns existing connection' do
      config.instance_variable_set(:@conn, 'TEST')

      expect(Faraday).not_to receive(:new)
      expect(config.connection).to eq('TEST')
    end

    it 'creates the connection' do
      expect(Faraday).to receive(:new).with('service_path', headers: 'base_request_headers', request: 'request_options')

      expect(faraday).to receive(:use).once.with(:breakers, { service_name: config.service_name })
      expect(faraday).to receive(:use).once.with(Faraday::Response::RaiseError)

      expect(faraday).to receive(:request).once.with(:multipart)
      expect(faraday).to receive(:request).once.with(:json)

      expect(faraday).to receive(:response).once.with(:betamocks) # use_mocks? => true
      expect(faraday).to receive(:response).once.with(:json)

      expect(faraday).to receive(:adapter).once.with(Faraday.default_adapter)

      config.connection
    end
  end

  # end RSpec.describe
end
