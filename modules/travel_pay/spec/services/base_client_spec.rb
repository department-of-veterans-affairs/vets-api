# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TravelPay::BaseClient do
  let(:client) { described_class.new }

  describe '#connection' do
    let(:server_url) { 'https://example.com' }

    before do
      allow(Settings.travel_pay).to receive(:service_name).and_return('travel_pay')
    end

    it 'returns a Faraday connection with json requests by default' do
      conn = client.connection(server_url:)
      handlers = conn.builder.handlers.map(&:name)

      expect(handlers).to include('Faraday::Request::Json')
    end

    it 'returns a Faraday connection with multipart requests when enabled' do
      conn = client.connection(server_url:, multipart: true)
      handlers = conn.builder.handlers.map(&:name)

      expect(handlers).to include('Faraday::Multipart::Middleware')
      expect(handlers).to include('Faraday::Request::UrlEncoded')
    end

    it 'sets timeout options on the connection' do
      conn = client.connection(server_url:)

      expect(conn.options.open_timeout).to eq(15)
      expect(conn.options.timeout).to eq(90)
    end

    context 'with custom timeout settings' do
      before do
        allow(Settings.travel_pay).to receive(:open_timeout).and_return(20)
        allow(Settings.travel_pay).to receive(:timeout).and_return(120)
      end

      it 'uses the custom timeout values' do
        conn = client.connection(server_url:)

        expect(conn.options.open_timeout).to eq(20)
        expect(conn.options.timeout).to eq(120)
      end
    end
  end

  describe '#mock_enabled?' do
    it 'returns the value of Settings.travel_pay.mock' do
      allow(Settings.travel_pay).to receive(:mock).and_return(true)
      expect(client.mock_enabled?).to be(true)

      allow(Settings.travel_pay).to receive(:mock).and_return(false)
      expect(client.mock_enabled?).to be(false)
    end
  end
end
