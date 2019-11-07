# frozen_string_literal: true

require 'rails_helper'

RSpec.describe GeocodingService do
  let(:street_address) { '3710 Southwest US Veterans Hospital Road' }
  let(:city) { 'Portland' }
  let(:state) { 'OR' }
  let(:zip) { '97239' }

  it 'converts an address to a lat/lng pair' do
    VCR.use_cassette('bing/geocoding/vha_648',
                     match_requests_on: [:method, VCR.request_matchers.uri_without_param(:key)]) do
      resp = subject.query(street_address, city, state, zip)
      expect(resp[:lat]).to eq(45.496474)
      expect(resp[:lng]).to eq(-122.68319)
    end
  end

  describe 'handling exceptions' do
    before do
      VCR.configure do |c|
        c.allow_http_connections_when_no_cassette = true
      end
    end

    after do
      VCR.configure do |c|
        c.allow_http_connections_when_no_cassette = false
      end
    end

    it 'raises an exception about an overloaded Bing server' do
      fake_response_body = {
        "resourceSets": [],
        "statusCode": '200',
        "statusDescription": 'OK'
      }

      fake_response_headers = {
        'cache-control' => 'no-cache',
        'transfer-encoding' => 'chunked',
        'content-type' => 'application/json; charset=utf-8',
        'vary' => 'Accept-Encoding',
        'server' => 'Microsoft-IIS/10.0',
        'x-ms-bm-ws-info' => '1'
      }

      stub_request(:get, %r{#{Settings.bing.base_api_url}/Locations})
        .to_return(status: 200, body: JSON.generate(fake_response_body), headers:
                   fake_response_headers)

      expect do
        subject.query(street_address, city, state, zip)
      end.to raise_error(Common::Exceptions::BingServiceError)
    end

    it 'raises an exception if any errors occur' do
      fake_response_body = { 'errors': ['An error happened!'] }

      fake_response_headers = { 'content-type' => 'application/json; charset=utf-8' }

      stub_request(:get, %r{#{Settings.bing.base_api_url}/Locations})
        .to_return(status: 200, body: JSON.generate(fake_response_body), headers:
                   fake_response_headers)

      expect do
        subject.query(street_address, city, state, zip)
      end.to raise_error(Common::Exceptions::BingServiceError)
    end
  end
end
