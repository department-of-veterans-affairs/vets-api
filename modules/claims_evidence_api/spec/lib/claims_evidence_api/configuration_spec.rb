# frozen_string_literal: true

require 'rails_helper'

require 'common/client/configuration/rest'
require 'claims_evidence_api/configuration'

RSpec.describe ClaimsEvidenceApi::Configuration do
  let(:base) { Common::Client::Configuration::REST }
  let(:config) { ClaimsEvidenceApi::Configuration.send(:new) }
  let(:settings) do
    OpenStruct.new({
                     base_url: 'https://fake-url.com',
                     breakers_error_threshold: 42,
                     jwt_secret: 'some-long-hash-value',
                     mock: false,
                     read_timeout: 23
                   })
  end

  before do
    allow(Settings).to receive(:claims_evidence_api).and_return(settings)
  end

  context 'valid settings' do
    it 'returns settings' do
      expect(config.service_settings).to eq(settings)
    end

    it 'has correct jwt_secret' do
      expect(config.service_settings.jwt_secret).to eq(settings.jwt_secret)
    end

    it 'returns service_path' do
      expect(config.service_path).to eq(settings.base_url)
      expect(config.base_path).to eq(settings.base_url)
    end

    it 'returns use_mocks' do
      expect(config.use_mocks?).to eq(settings.mock)
    end
  end

  context 'expected constants' do
    it 'returns service_name' do
      expect(config.service_name).to eq('ClaimsEvidenceApi')
    end

    it 'returns breakers_error_threshold' do
      expect(config.breakers_error_threshold).to eq(42)
    end

    it 'returns read_timeout' do
      expect(config.service_settings.read_timeout).to eq(23)
    end
  end

  describe '#base_request_headers' do
    it 'returns expected headers' do
      expect_any_instance_of(ClaimsEvidenceApi::JwtGenerator).to receive(:encode_jwt).and_call_original

      expected = base.base_request_headers.merge({ 'Authorization' => /Bearer .+/ })

      headers = config.base_request_headers
      expect(headers).to match(hash_including(**expected))
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
