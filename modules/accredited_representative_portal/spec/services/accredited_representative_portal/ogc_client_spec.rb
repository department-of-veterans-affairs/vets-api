# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AccreditedRepresentativePortal::OgcClient do
  let(:fake_settings) do
    OpenStruct.new(
      gclaws: OpenStruct.new(
        accreditation: OpenStruct.new(
          api_key: 'secret-key',
          origin: 'https://arp.va.gov',
          icn: OpenStruct.new(url: 'https://ogc.example/api/icn')
        )
      )
    )
  end

  let(:logger) { instance_double(Logger, info: true, error: true) }

  before do
    stub_const('Settings', fake_settings)
    allow(Rails).to receive(:logger).and_return(logger)
  end

  describe '#initialize' do
    it 'builds a config hash from Settings' do
      client = described_class.new
      expect(client.config).to include(
        api_key: 'secret-key',
        origin: 'https://arp.va.gov',
        icn_endpoint_url: 'https://ogc.example/api/icn'
      )
    end
  end

  describe '#find_registration_numbers_for_icn' do
    let(:faraday) { instance_double(Faraday::Connection) }

    before { allow(Faraday).to receive(:new).and_return(faraday) }

    it 'returns nil when icn is blank' do
      expect(described_class.new.find_registration_numbers_for_icn(nil)).to be_nil
      expect(described_class.new.find_registration_numbers_for_icn('')).to be_nil
    end

    it 'returns registration numbers when status=200 and body has non-empty registrationNumbers' do
      body = { registrationNumbers: %w[REG001 REG002] }.to_json
      response = instance_double(Faraday::Response, status: 200, body:)
      expect(faraday).to receive(:post) do |url, payload, headers|
        expect(url).to eq('https://ogc.example/api/icn')
        expect(JSON.parse(payload)).to eq({ 'icnNo' => '123', 'multiMatchInd' => true })
        expect(headers).to include('x-api-key' => 'secret-key', 'Origin' => 'https://arp.va.gov')
        response
      end

      result = described_class.new.find_registration_numbers_for_icn('123')
      expect(result).to eq(%w[REG001 REG002])
    end

    it 'returns nil when status=200 but registrationNumbers missing or empty' do
      response1 = instance_double(Faraday::Response, status: 200, body: { foo: 'bar' }.to_json)
      response2 = instance_double(Faraday::Response, status: 200, body: { registrationNumbers: [] }.to_json)

      expect(faraday).to receive(:post).and_return(response1)
      expect(described_class.new.find_registration_numbers_for_icn('123')).to be_nil

      expect(faraday).to receive(:post).and_return(response2)
      expect(described_class.new.find_registration_numbers_for_icn('123')).to be_nil
    end

    it 'logs and returns nil when body is invalid JSON' do
      response = instance_double(Faraday::Response, status: 200, body: 'not-json')
      expect(faraday).to receive(:post).and_return(response)

      expect(described_class.new.find_registration_numbers_for_icn('123')).to be_nil
      expect(logger).to have_received(:error).with(a_string_matching(/Error parsing OGC response/))
    end

    it 'logs and returns nil when Faraday raises' do
      expect(faraday).to receive(:post).and_raise(StandardError, 'kaboom')

      expect(described_class.new.find_registration_numbers_for_icn('123')).to be_nil
      expect(logger).to have_received(:error).with(a_string_matching(/ICN: kaboom/))
    end

    it 'returns nil when non-200 status' do
      response = instance_double(Faraday::Response, status: 500, body: { message: 'err' }.to_json)
      expect(faraday).to receive(:post).and_return(response)

      expect(described_class.new.find_registration_numbers_for_icn('123')).to be_nil
    end
  end

  describe '#post_icn_and_registration_combination' do
    let(:faraday) { instance_double(Faraday::Connection) }

    before { allow(Faraday).to receive(:new).and_return(faraday) }

    it 'returns nil when icn or registration_number is blank' do
      client = described_class.new
      expect(client.post_icn_and_registration_combination(nil, 'REG001')).to be_nil
      expect(client.post_icn_and_registration_combination('123', nil)).to be_nil
      expect(client.post_icn_and_registration_combination('', 'REG001')).to be_nil
      expect(client.post_icn_and_registration_combination('123', '')).to be_nil
    end

    it 'returns :conflict and logs when status=409' do
      response = instance_double(Faraday::Response, status: 409, body: '')
      expect(faraday).to receive(:post) do |url, payload, headers|
        expect(url).to eq('https://ogc.example/api/icn/REG001')
        expect(JSON.parse(payload)).to include('icnNo' => '123', 'registrationNo' => 'REG001', 'multiMatchInd' => true)
        expect(headers).to include('x-api-key' => 'secret-key')
        response
      end

      result = described_class.new.post_icn_and_registration_combination('123', 'REG001')
      expect(result).to eq(:conflict)
      expect(logger).to have_received(:info).with(a_string_matching(/Conflict detected/))
    end

    it 'returns true when status=200 and body present' do
      response = instance_double(Faraday::Response, status: 200, body: '{"ok":true}')
      expect(faraday).to receive(:post).and_return(response)

      expect(described_class.new.post_icn_and_registration_combination('123', 'REG001')).to be(true)
    end

    it 'returns false when status=200 but body empty' do
      response = instance_double(Faraday::Response, status: 200, body: '')
      expect(faraday).to receive(:post).and_return(response)

      expect(described_class.new.post_icn_and_registration_combination('123', 'REG001')).to be(false)
    end

    it 'returns false when non-200 and not 409' do
      response = instance_double(Faraday::Response, status: 500, body: '{"error":"nope"}')
      expect(faraday).to receive(:post).and_return(response)

      expect(described_class.new.post_icn_and_registration_combination('123', 'REG001')).to be(false)
    end

    it 'logs and returns false when Faraday raises' do
      expect(faraday).to receive(:post).and_raise(StandardError, 'boom')

      expect(described_class.new.post_icn_and_registration_combination('123', 'REG001')).to be(false)
      expect(logger).to have_received(:error).with(a_string_matching(/combination: boom/))
    end
  end
end
