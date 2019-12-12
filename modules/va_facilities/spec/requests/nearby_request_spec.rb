# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Nearby Facilities API endpoint', type: :request do
  let(:base_query_path) { '/services/va_facilities/v0/nearby' }
  let(:address_params) do
    {
      street_address: '3710 Southwest US Veterans Hospital Road',
      city: 'Portland',
      state: 'OR',
      zip: '97239'
    }
  end
  let(:coord_params) { { lat: 45.4967668, lng: -122.6832211 } }
  let(:accept_json) { { 'HTTP_ACCEPT' => 'application/json' } }
  let(:error) { JSON.parse(response.body) }
  let(:create_bands) do
    create :vha_648
    create :vha_648GI
    create :ten_mins_648
    create :twenty_mins_648
    create :ten_mins_648GI
    create :twenty_mins_648GI
  end

  describe 'get drive time' do
    it 'can be retrieved with an address' do
      create_bands

      VCR.use_cassette('bing/geocoding/vha_648',
                       match_requests_on: [:method, VCR.request_matchers.uri_without_param(:key)]) do
        get base_query_path,
            params: { street_address: '3710 Southwest US Veterans Hospital Road',
                      city: 'Portland', state: 'OR', zip: '97239', drive_time: '10' },
            headers: { 'HTTP_ACCEPT' => 'application/json' }

        expect(response).to be_successful
        expect(response.body).to be_a(String)

        json = JSON.parse(response.body)
        nearby_result = json['data'].first

        expect(json['data'].length).to eq(1)
        expect(nearby_result['attributes']['min_time']).to eq(0)
        expect(nearby_result['attributes']['max_time']).to eq(10)
        expect(nearby_result['id']).to eq('vha_648')
        expect(nearby_result['relationships']['va_facility']['links']['related'])
          .to eql('/services/va_facilities/v0/facilities/vha_648')
        expect(json['meta']['pagination'])
          .to include('current_page' => 1, 'per_page' => 20, 'total_pages' => 1, 'total_entries' => 1)
        expect(json['links']['related']).to eq('/services/va_facilities/v0/facilities?ids=vha_648')
      end
    end

    it 'can be retrieved with a lat/lng' do
      create_bands

      get base_query_path,
          params: { lat: 45.4967668, lng: -122.6832211, drive_time: '10' },
          headers: { 'HTTP_ACCEPT' => 'application/json' }

      expect(response).to be_successful
      expect(response.body).to be_a(String)

      json = JSON.parse(response.body)
      nearby_result = json['data'].first

      expect(json['data'].length).to eq(1)
      expect(nearby_result['attributes']['min_time']).to eq(0)
      expect(nearby_result['attributes']['max_time']).to eq(10)
      expect(nearby_result['id']).to eq('vha_648')
      expect(nearby_result['relationships']['va_facility']['links']['related'])
        .to eql('/services/va_facilities/v0/facilities/vha_648')
      expect(json['meta']['pagination'])
        .to include('current_page' => 1, 'per_page' => 20, 'total_pages' => 1, 'total_entries' => 1)
      expect(json['links']['related']).to eq('/services/va_facilities/v0/facilities?ids=vha_648')
    end

    it 'can be filtered by services' do
      create_bands

      get base_query_path,
          params: { lat: 45.4967668, lng: -122.6832211,
                    drive_time: '20', 'services[]': 'EmergencyCare' },
          headers: { 'HTTP_ACCEPT' => 'application/json' }

      expect(response).to be_successful
      expect(response.body).to be_a(String)

      json = JSON.parse(response.body)
      nearby_result = json['data'].first

      expect(json['data'].length).to eq(1)
      expect(nearby_result['attributes']['min_time']).to eq(0)
      expect(nearby_result['attributes']['max_time']).to eq(10)
      expect(nearby_result['id']).to eq('vha_648')
      expect(nearby_result['relationships']['va_facility']['links']['related'])
        .to eql('/services/va_facilities/v0/facilities/vha_648')
      expect(json['meta']['pagination'])
        .to include('current_page' => 1, 'per_page' => 20, 'total_pages' => 1, 'total_entries' => 1)
      expect(json['links']['related']).to eq('/services/va_facilities/v0/facilities?ids=vha_648')
    end

    it 'temporarily returns no results for Podiatry' do
      create_bands

      get base_query_path,
          params: { lat: 45.4967668, lng: -122.6832211,
                    drive_time: '20', 'services[]': 'Podiatry' },
          headers: { 'HTTP_ACCEPT' => 'application/json' }

      expect(response).to be_successful
      expect(response.body).to be_a(String)

      json = JSON.parse(response.body)

      expect(json['data'].length).to eq(0)
    end

    it 'temporarily returns no results for Nutrition' do
      create_bands

      get base_query_path,
          params: { lat: 45.4967668, lng: -122.6832211,
                    drive_time: '20', 'services[]': 'Nutrition' },
          headers: { 'HTTP_ACCEPT' => 'application/json' }

      expect(response).to be_successful
      expect(response.body).to be_a(String)

      json = JSON.parse(response.body)

      expect(json['data'].length).to eq(0)
    end
  end

  describe 'bing errors' do
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

    it 'handles an empty result set from bing' do
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
    end

    it 'handles a rate limiting error from bing' do
      create_bands

      fake_response_body = {
        "authenticationResultCode": 'ValidCredentials',
        "brandLogoUri": 'blah',
        "copyright": 'Copyright',
        "errors": [
          { "errorCode": '', "errorDetails": ['Too many requests'] }
        ],
        "resourceSets": [],
        "statusCode": '429',
        "statusDescription": 'Too many requests',
        "traceId": 'gobbledygook'
      }

      stub_request(:get, /#{Settings.bing.base_api_url}/)
        .to_return(status: 429, body: JSON.generate(fake_response_body), headers:
                   { 'cache-control' => 'no-cache',
                     'transfer-encoding' => 'chunked',
                     'content-type' => 'application/json; charset=utf-8',
                     'vary' => 'Accept-Encoding',
                     'server' => 'Microsoft-IIS/10.0' })

      get base_query_path,
          params: { street_address: '1 VA Center', city: 'Augusta', state: 'ME', zip: '04330', drive_time: '20' },
          headers: { 'HTTP_ACCEPT' => 'application/json' }

      expect(response.status).to eq(500)
      expect(response.body).to be_a(String)
      json = JSON.parse(response.body)
      expect(json['errors'].size).to eq(1)
      error = json['errors'].first
      expect(error['title']).to eq('Bing Service Error')
      expect(error['status']).to eq('500')
      expect(error['detail'].first).to eq('Too many requests')
    end
  end

  describe 'with invalid request parameters' do
    it 'returns 400 for missing street_address' do
      get base_query_path, params: { city: 'Baltimore', state: 'MD', zip: '21230' }, headers: accept_json
      expect(response).to have_http_status(:bad_request)
    end
    it 'returns 400 for missing city' do
      get base_query_path, params: { street: '2400 Fort Ave', state: 'MD', zip: '21230' }, headers: accept_json
      expect(response).to have_http_status(:bad_request)
    end
    it 'returns 400 for missing state' do
      get base_query_path, params: { street: '2400 Fort Ave', city: 'Baltimore', zip: '21230' }, headers: accept_json
      expect(response).to have_http_status(:bad_request)
    end
    it 'returns 400 for missing zip' do
      get base_query_path, params: { street: '2400 Fort Ave', city: 'Baltimore', state: 'MD' }, headers: accept_json
      expect(response).to have_http_status(:bad_request)
    end
    it 'returns 400 for non-integer drive_time' do
      get base_query_path, params: coord_params.merge(drive_time: 'sixty'), headers: accept_json
      expect(response).to have_http_status(:bad_request)
    end
    it 'returns 400 for an unknown health service' do
      get base_query_path, params: coord_params.merge('services[]': 'OilChange'), headers: accept_json
      expect(response).to have_http_status(:bad_request)
    end
    it 'returns 400 for ambiguous location request' do
      get base_query_path, params: coord_params.merge(address_params), headers: accept_json
      expect(response).to have_http_status(:bad_request)
    end
    it 'returns 400 for missing lng' do
      get base_query_path, params: { lat: 40.3 }, headers: accept_json
      expect(response).to have_http_status(:bad_request)
    end
    it 'returns 400 for missing lat' do
      get base_query_path, params: { lng: 40.3 }, headers: accept_json
      expect(response).to have_http_status(:bad_request)
    end
    it 'returns 400 non integer lat' do
      get base_query_path, params: { lat: 'eighty', lng: 40.3 }, headers: accept_json
      expect(response).to have_http_status(:bad_request)
    end
    it 'returns 400 non integer lng' do
      get base_query_path, params: { lat: 80.4, lng: 'forty' }, headers: accept_json
      expect(response).to have_http_status(:bad_request)
    end
  end
end
