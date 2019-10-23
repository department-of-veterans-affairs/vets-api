# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Nearby Facilities API endpoint', type: :request do
  let(:base_query_path) { '/services/va_facilities/v1/nearby' }
  let(:drivetime_bands) do
    create :ten_mins_402
    create :twenty_mins_402
    create :thirty_mins_402
  end

  before do
    create :vha_402
    drivetime_bands
  end

  describe 'get drive time' do
    it 'can be retrieved with an address' do
      VCR.use_cassette('bing/geocoding/vha_402',
                       match_requests_on: [:method, VCR.request_matchers.uri_without_param(:key)]) do
        get base_query_path,
            params: { street_address: '1 VA Center', city: 'Augusta', state: 'ME', zip: '04330', drive_time: '20' },
            headers: { 'HTTP_ACCEPT' => 'application/json' }
            
        expect(response).to be_successful
        expect(response.body).to be_a(String)
        
        json = JSON.parse(response.body)
        nearby_result = json['data'].first
        
        expect(json['data'].length).to eq(1)
        expect(nearby_result['attributes']['drivetime_band_min']).to eq(0)
        expect(nearby_result['attributes']['drivetime_band_max']).to eq(10)
        expect(nearby_result['id']).to eq('vha_402')
        expect(nearby_result['relationships']['va_facilities']['links']['related'])
          .to eql('/services/va_facilities/v0/facilities/vha_402')
        expect(json['meta']['pagination'])
          .to include('current_page' => 1, 'per_page' => 20, 'total_pages' => 1, 'total_entries' => 1)
      end
    end

    it 'can be retrieved with a lat/lng' do
      get base_query_path,
          params: { lat: 44.27874833, lng: -69.70363833, drive_time: '20' },
          headers: { 'HTTP_ACCEPT' => 'application/json' }

      expect(response).to be_successful
      expect(response.body).to be_a(String)

      json = JSON.parse(response.body)
      nearby_result = json['data'].first
      
      expect(json['data'].length).to eq(1)
      expect(nearby_result['attributes']['drivetime_band_min']).to eq(0)
      expect(nearby_result['attributes']['drivetime_band_max']).to eq(10)
      expect(nearby_result['id']).to eq('vha_402')
      expect(nearby_result['relationships']['va_facilities']['links']['related'])
        .to eql('/services/va_facilities/v0/facilities/vha_402')
      expect(json['meta']['pagination'])
        .to include('current_page' => 1, 'per_page' => 20, 'total_pages' => 1, 'total_entries' => 1)
    end
  end

  describe 'bing errors' do
    it 'handles an empty result set from bing' do
      VCR.configure do |c|
        c.allow_http_connections_when_no_cassette = true
      end

      fake_response_body = {
        "authenticationResultCode": 'ValidCredentials',
        "brandLogoUri": 'blah',
        "copyright": 'Copyright',
        "resourceSets": [],
        "statusCode": '200',
        "statusDescription": 'OK',
        "traceId": 'gobbledygook'
      }

      fake_response_headers = {
        'cache-control' => 'no-cache',
        'transfer-encoding' => 'chunked',
        'content-type' => 'application/json; charset=utf-8',
        'vary' => 'Accept-Encoding',
        'server' => 'Microsoft-IIS/10.0'
      }

      stub_request(:get, %r{#{Settings.bing.base_api_url}/Locations})
        .to_return(status: 200, body: JSON.generate(fake_response_body), headers:
              fake_response_headers)

      get base_query_path,
          params: { street_address: '1 VA Center', city: 'Augusta', state: 'ME', zip: '04330', drive_time: '20' },
          headers: { 'HTTP_ACCEPT' => 'application/json' }

      expect(response.status).to eq(200)
      expect(response.body).to be_a(String)
      json = JSON.parse(response.body)
      expect(json['data']).to be_empty
      expect(json['meta']).to have_key('pagination')

      VCR.configure do |c|
        c.allow_http_connections_when_no_cassette = false
      end
    end
  end
end
