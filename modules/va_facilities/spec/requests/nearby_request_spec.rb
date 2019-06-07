# frozen_string_literal: true

require 'rails_helper'
require 'cgi'
require 'uri'

RSpec.describe 'Nearby Facilities API endpoint', type: :request do
  include SchemaMatchers

  let(:base_query_path) { '/services/va_facilities/v1/nearby' }
  let(:address_params) { '?street_address=9729%20SE%20222nd%20Dr&city=Damascus&state=OR&zip=97089&drive_time=60' }
  let(:no_health_services_address_params) { '?street_address=197%20East%20Main%20Street&city=Fort%20Kent&state=ME&zip=04743&drive_time=60' }
  let(:empty_address) { '?street_address=9729%20SE%20222nd%20Dr&city=Damascus&state=OR&zip=97089&drive_time=1' }

  let(:accept_json) { { 'HTTP_ACCEPT' => 'application/json' } }
  let(:accept_geojson) { { 'HTTP_ACCEPT' => 'application/vnd.geo+json' } }

  let(:setup_pdx) do
    %w[vc_0617V nca_907 vha_648 vha_648A4 vha_648GI vba_348 vba_348a vba_348d vba_348e vba_348h].map { |id| create id }
  end

  def parse_link_header(header)
    links = header.split(',').map(&:strip)
    links = links.map { |x| x.split(';').map(&:strip).reverse }
    links.each_with_object({}) do |(f, s), h|
      k = f.sub('rel="', '').sub('"', '')
      v = query_params(s.tr('<>', ''))
      h[k] = v
    end
  end

  def query_params(url)
    CGI.parse(URI.parse(url).query)
  end

  context 'when requesting JSON API format' do
    it 'responds to GET #index' do
      setup_pdx
      VCR.use_cassette('bing/isochrone/pdx_drive_time_60',
                       match_requests_on: [:method, VCR.request_matchers.uri_without_param(:key)]) do
        get base_query_path + address_params, params: nil, headers: accept_json
        expect(response).to be_success
        expect(response.body).to be_a(String)
        json = JSON.parse(response.body)
        expect(json['data'].length).to eq(10)
        expect(json['meta']['distances']).to eq([])
      end
    end

    it 'responds with pagination links' do
      setup_pdx
      VCR.use_cassette('bing/isochrone/pdx_drive_time_60',
                       match_requests_on: [:method, VCR.request_matchers.uri_without_param(:key)]) do
        get base_query_path + address_params, params: nil, headers: accept_json
        expect(response).to be_success
        json = JSON.parse(response.body)
        expect(json).to have_key('links')
        links = json['links']
        expect(links).to have_key('self')
        expect(links).to have_key('first')
        expect(links).to have_key('last')
        expect(links).to have_key('prev')
        expect(links).to have_key('next')
      end
    end

    it 'responds with pagination metadata' do
      setup_pdx
      VCR.use_cassette('bing/isochrone/pdx_drive_time_60',
                       match_requests_on: [:method, VCR.request_matchers.uri_without_param(:key)]) do
        get base_query_path + address_params, params: nil, headers: accept_json
        expect(response).to be_success
        json = JSON.parse(response.body)
        expect(json).to have_key('meta')
        expect(json['meta']).to have_key('pagination')
        pagination = json['meta']['pagination']
        expect(pagination).to have_key('current_page')
        expect(pagination).to have_key('per_page')
        expect(pagination).to have_key('total_pages')
        expect(pagination).to have_key('total_entries')
      end
    end

    it 'paginates according to parameters' do
      setup_pdx
      VCR.use_cassette('bing/isochrone/pdx_drive_time_60',
                       match_requests_on: [:method, VCR.request_matchers.uri_without_param(:key)]) do
        get base_query_path + address_params + '&page=2&per_page=3', params: nil, headers: accept_json
        expect(response).to be_success
        json = JSON.parse(response.body)
        expect(json['data'].length).to eq(3)
        links = json['links']
        expect(query_params(links['self'])['page']).to eq(['2'])
        expect(query_params(links['self'])['per_page']).to eq(['3'])
        pagination = json['meta']['pagination']
        expect(pagination['current_page']).to eq(2)
        expect(pagination['per_page']).to eq(3)
        expect(pagination['total_pages']).to eq(4)
        expect(pagination['total_entries']).to eq(10)
      end
    end

    it 'paginates empty result set' do
      setup_pdx
      VCR.use_cassette('bing/isochrone/pdx_drive_time_1',
                       match_requests_on: [:method, VCR.request_matchers.uri_without_param(:key)]) do
        get base_query_path + empty_address, params: nil, headers: accept_json
        expect(response).to be_success
        json = JSON.parse(response.body)
        expect(json['data'].length).to eq(0)
        links = json['links']
        expect(query_params(links['last'])['page']).to eq(['1'])
        pagination = json['meta']['pagination']
        expect(pagination['total_pages']).to eq(1)
        expect(pagination['total_entries']).to eq(0)
      end
    end

    it 'responds with lng in v1 instead of long' do
      setup_pdx
      VCR.use_cassette('bing/isochrone/pdx_drive_time_60',
                       match_requests_on: [:method, VCR.request_matchers.uri_without_param(:key)]) do
        get base_query_path + address_params, params: nil, headers: accept_json

        expect(response).to be_success
        json = JSON.parse(response.body)
        lng = json['data'][0]['attributes']['lng']
        expect(lng).to eq(-122.68287208)
      end
    end

    it 'responds with wait times as part of health services in v1' do
      setup_pdx
      VCR.use_cassette('bing/isochrone/pdx_drive_time_60',
                       match_requests_on: [:method, VCR.request_matchers.uri_without_param(:key)]) do
        get base_query_path + address_params, params: nil, headers: accept_json

        expect(response).to be_success
        json = JSON.parse(response.body)
        health_service = json['data'][0]['attributes']['services']['health'][0]

        expect(health_service['service']).to eq('PrimaryCare')
        expect(health_service['wait_times']['new']).to eq(27.0)
        expect(health_service['wait_times']['established']).to eq(6.0)
        expect(health_service['wait_times']['effective_date']).to eq('2018-03-05')
      end
    end
  end

  context 'when requesting GeoJSON format' do
    it 'responds to GET #index' do
      setup_pdx
      VCR.use_cassette('bing/isochrone/pdx_drive_time_60',
                       match_requests_on: [:method, VCR.request_matchers.uri_without_param(:key)]) do
        get base_query_path + address_params, params: nil, headers: accept_geojson
        expect(response).to be_success
        expect(response.body).to be_a(String)
        json = JSON.parse(response.body)
        expect(json['type']).to eq('FeatureCollection')
        expect(json['features'].length).to eq(10)
        expect(response.headers['Content-Type']).to eq 'application/vnd.geo+json; charset=utf-8'
      end
    end

    it 'responds with pagination link header' do
      setup_pdx
      VCR.use_cassette('bing/isochrone/pdx_drive_time_60',
                       match_requests_on: [:method, VCR.request_matchers.uri_without_param(:key)]) do
        get base_query_path + address_params, params: nil, headers: accept_geojson
        expect(response).to be_success
        expect(response.headers['Link']).to be_present
        parsed = parse_link_header(response.headers['Link'])
        expect(parsed).to have_key('self')
        expect(parsed).to have_key('first')
        expect(parsed).to have_key('last')
        expect(parsed).not_to have_key('prev')
        expect(parsed).not_to have_key('next')
      end
    end

    it 'paginates according to parameters' do
      setup_pdx
      VCR.use_cassette('bing/isochrone/pdx_drive_time_60',
                       match_requests_on: [:method, VCR.request_matchers.uri_without_param(:key)]) do
        get base_query_path + address_params + '&page=2&per_page=3', params: nil, headers: accept_geojson
        expect(response).to be_success
        json = JSON.parse(response.body)
        expect(json['type']).to eq('FeatureCollection')
        expect(json['features'].length).to eq(3)
        expect(response.headers['Link']).to be_present
        parsed = parse_link_header(response.headers['Link'])
        expect(parsed['self']['page']).to eq(['2'])
        expect(parsed['first']['page']).to eq(['1'])
        expect(parsed['last']['page']).to eq(['4'])
        expect(parsed['prev']['page']).to eq(['1'])
        expect(parsed['next']['page']).to eq(['3'])
      end
    end

    it 'paginates empty result set' do
      setup_pdx
      VCR.use_cassette('bing/isochrone/pdx_drive_time_1',
                       match_requests_on: [:method, VCR.request_matchers.uri_without_param(:key)]) do
        get base_query_path + empty_address, params: nil, headers: accept_geojson
        expect(response).to be_success
        json = JSON.parse(response.body)
        expect(json['type']).to eq('FeatureCollection')
        expect(json['features'].length).to eq(0)
        expect(response.headers['Link']).to be_present
        parsed = parse_link_header(response.headers['Link'])
        expect(parsed['self']['page']).to eq(['1'])
        expect(parsed['first']['page']).to eq(['1'])
        expect(parsed['last']['page']).to eq(['1'])
      end
    end

    it 'responds with wait times as part of health services in v1' do
      setup_pdx
      VCR.use_cassette('bing/isochrone/pdx_drive_time_60',
                       match_requests_on: [:method, VCR.request_matchers.uri_without_param(:key)]) do
        get base_query_path + address_params, params: nil, headers: accept_geojson

        expect(response).to be_success
        json = JSON.parse(response.body)
        health_service = json['features'][0]['properties']['services']['health'][0]

        expect(health_service['service']).to eq('PrimaryCare')
        expect(health_service['wait_times']['new']).to eq(27.0)
        expect(health_service['wait_times']['established']).to eq(6.0)
        expect(health_service['wait_times']['effective_date']).to eq('2018-03-05')
      end
    end

    it 'responds successfully even if health facilities return no health services' do
      create 'vha_402QA'
      VCR.use_cassette('bing/isochrone/no_health_services_drive_time',
                       match_requests_on: [:method, VCR.request_matchers.uri_without_param(:key)]) do

        get base_query_path + no_health_services_address_params, params: nil, headers: accept_json
        expect(response).to be_success
        
        json = JSON.parse(response.body)
        health_services = json['data'][0]['attributes']['services']['health']
        expect(health_services.length).to eq(0)
      end
    end
  end

  context 'with invalid request parameters' do
    it 'returns 400 for missing street_address' do
      get base_query_path + '?city=Baltimore&state=MD&zip=21230', params: nil, headers: accept_json
      expect(response).to have_http_status(:bad_request)
    end
    it 'returns 400 for missing city' do
      get base_query_path + '?street_address=2400%20E%20Fort%20Ave&state=MD&zip=21230',
          params: nil, headers: accept_json
      expect(response).to have_http_status(:bad_request)
    end
    it 'returns 400 for missing state' do
      get base_query_path + '?street_address=2400%20E%20Fort%20Ave&city=Baltimore&zip=21230',
          params: nil, headers: accept_json
      expect(response).to have_http_status(:bad_request)
    end
    it 'returns 400 for missing zip' do
      get base_query_path + '?street_address=2400%20E%20Fort%20Ave&state=MD', params: nil, headers: accept_json
      expect(response).to have_http_status(:bad_request)
    end
    it 'returns 400 for non-integer drive_time' do
      get base_query_path + address_params + '&drive_time=sixty', params: nil, headers: accept_json
      expect(response).to have_http_status(:bad_request)
    end
    it 'returns 400 for invalid type parameter' do
      get base_query_path + address_params + '&type=bogus'
      expect(response).to have_http_status(:bad_request)
    end
    it 'returns 400 for query with services but no type' do
      get base_query_path + address_params + '&services[]=EyeCare'
      expect(response).to have_http_status(:bad_request)
    end
    it 'returns 400 for health query with unknown service' do
      get base_query_path + address_params + '&type=health&services[]=OilChange'
      expect(response).to have_http_status(:bad_request)
    end
  end
end
