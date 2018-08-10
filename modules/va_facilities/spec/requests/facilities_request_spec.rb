# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Facilities API endpoint', type: :request do
  include SchemaMatchers

  BASE_QUERY_PATH = '/services/va_facilities/v0/facilities?'
  PDX_BBOX = 'bbox[]=-122.440689&bbox[]=45.451913&bbox[]=-122.786758&bbox[]=45.64'

  let(:setup_pdx) do
    %w[vc_0617V nca_907 vha_648 vha_648A4 vha_648GI vba_348 vba_348a vba_348d vba_348e vba_348h].map { |id| create id }
  end
  let(:accept_json) { { 'HTTP_ACCEPT' => 'application/json' } }
  let(:accept_geojson) { { 'HTTP_ACCEPT' => 'application/vnd.geo+json' } }
  let(:accept_csv) { { 'HTTP_ACCEPT' => 'text/csv' } }

  context 'when requesting JSON API format' do
    it 'responds to GET #show for VHA prefix' do
      create :vha_648A4
      get '/services/va_facilities/v0/facilities/vha_648A4', nil, accept_json
      expect(response).to be_success
      expect(response.body).to be_a(String)
      json = JSON.parse(response.body)
      expect(json['data']['id']).to eq('vha_648A4')
    end

    it 'responds to GET #index with bbox' do
      setup_pdx
      get BASE_QUERY_PATH + PDX_BBOX, nil, accept_json
      expect(response).to be_success
      expect(response.body).to be_a(String)
      json = JSON.parse(response.body)
      expect(json['data'].length).to eq(10)
    end
  end

  context 'when requesting GeoJSON format' do
    it 'responds to GET #show for VHA prefix' do
      create :vha_648A4
      get '/services/va_facilities/v0/facilities/vha_648A4', nil, accept_geojson
      expect(response).to be_success
      expect(response.headers['Content-Type']).to eq 'application/vnd.geo+json; charset=utf-8'
      expect(response.body).to be_a(String)
      json = JSON.parse(response.body)
      expect(json['type']).to eq('Feature')
      expect(json['properties']['id']).to eq('vha_648A4')
    end

    it 'responds to GET #index with bbox' do
      setup_pdx
      get BASE_QUERY_PATH + PDX_BBOX, nil, accept_geojson
      expect(response).to be_success
      expect(response.headers['Content-Type']).to eq 'application/vnd.geo+json; charset=utf-8'
      expect(response.body).to be_a(String)
      json = JSON.parse(response.body)
      expect(json['type']).to eq('FeatureCollection')
      expect(json['features'].length).to eq(10)
    end
  end

  context 'when requesting all facilities' do
    it 'responds to GeoJSON format' do
      setup_pdx
      get '/services/va_facilities/v0/facilities/all', nil, accept_geojson
      expect(response).to be_success
      expect(response.headers['Content-Type']).to eq 'application/vnd.geo+json; charset=utf-8'
      expect(response.body).to be_a(String)
      json = JSON.parse(response.body)
      expect(json['type']).to eq('FeatureCollection')
    end

    it 'responds to CSV format' do
      setup_pdx
      get '/services/va_facilities/v0/facilities/all', nil, accept_csv
      expect(response).to be_success
      expect(response.headers['Content-Type']).to eq 'text/csv'
      expect(response.body).to be_a(String)
    end
  end

  context 'with invalid request parameters' do
    it 'returns 400 for nonsense bbox' do
      get BASE_QUERY_PATH + 'bbox[]=everywhere'
      expect(response).to have_http_status(:bad_request)
    end
    it 'returns 400 for non-array bbox' do
      get BASE_QUERY_PATH + 'bbox=-90,180,45,80'
      expect(response).to have_http_status(:bad_request)
    end
    it 'returns 400 for too many elements' do
      get BASE_QUERY_PATH + 'bbox[]=-45&bbox[]=-45&bbox[]=45&bbox=45&bbox=100'
      expect(response).to have_http_status(:bad_request)
    end
    it 'returns 400 for not enough elements' do
      get BASE_QUERY_PATH + 'bbox[]=-45&bbox[]=-45&bbox[]=45'
      expect(response).to have_http_status(:bad_request)
    end
    it 'returns 400 for non-numeric elements' do
      get BASE_QUERY_PATH + 'bbox[]=-45&bbox[]=-45&bbox[]=45&bbox=abc'
      expect(response).to have_http_status(:bad_request)
    end
    it 'returns 400 for invalid type parameter' do
      get BASE_QUERY_PATH + PDX_BBOX + '&type=bogus'
      expect(response).to have_http_status(:bad_request)
    end
    it 'returns 400 for query with services but no type' do
      get BASE_QUERY_PATH + PDX_BBOX + '&services[]=EyeCare'
      expect(response).to have_http_status(:bad_request)
    end
    it 'returns 400 for health query with unknown service' do
      get BASE_QUERY_PATH + PDX_BBOX + '&type=health&services[]=OilChange'
      expect(response).to have_http_status(:bad_request)
    end
  end
end
