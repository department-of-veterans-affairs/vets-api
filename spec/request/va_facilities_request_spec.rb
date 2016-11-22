# frozen_string_literal: true
require 'rails_helper'

RSpec.describe 'VA GIS Integration', type: :request do
  BASE_QUERY_PATH = '/v0/facilities/va?'
  PDX_BBOX = 'bbox[]=-122.440689&bbox[]=45.451913&bbox[]=-122.786758&bbox[]=45.64'
  NY_BBOX = 'bbox[]=-73.401&bbox[]=40.685&bbox[]=-77.36&bbox[]=43.03'
  DEGEN_BBOX = 'bbox[]=-100&bbox[]=45&bbox[]=-100&bbox[]=45'

  it 'responds to GET #show for VHA prefix' do
    VCR.use_cassette('facilities/va/bulk_load') do
      get '/v0/facilities/va/vha_648A4'
      expect(response).to be_success
      expect(response.body).to be_a(String)
      json = JSON.parse(response.body)
      expect(json['data']['id']).to eq('vha_648A4')
    end
  end

  it 'responds to GET #show for NCA prefix' do
    VCR.use_cassette('facilities/va/bulk_load') do
      get '/v0/facilities/va/nca_888'
      expect(response).to be_success
      expect(response.body).to be_a(String)
      json = JSON.parse(response.body)
      expect(json['data']['id']).to eq('nca_888')
    end
  end

  it 'responds to GET #show for VBA prefix' do
    VCR.use_cassette('facilities/va/bulk_load') do
      get '/v0/facilities/va/vba_314c'
      expect(response).to be_success
      expect(response.body).to be_a(String)
      json = JSON.parse(response.body)
      expect(json['data']['id']).to eq('vba_314c')
    end
  end

  it 'responds to GET #show without prefix' do
    VCR.use_cassette('facilities/va/bulk_load') do
      get '/v0/facilities/va/684A4'
      expect(response).to have_http_status(:not_found)
    end
  end

  it 'responds to GET #show non-existent' do
    VCR.use_cassette('facilities/va/bulk_load') do
      get '/v0/facilities/va/nca_9999999'
      expect(response).to have_http_status(:not_found)
    end
  end

  it 'responds to GET #index with bbox' do
    VCR.use_cassette('facilities/va/bulk_load') do
      get BASE_QUERY_PATH + PDX_BBOX
      expect(response).to be_success
      expect(response.body).to be_a(String)
      json = JSON.parse(response.body)
      expect(json['data'].length).to eq(9)
    end
  end

  it 'responds to GET #index with bbox and health type' do
    VCR.use_cassette('facilities/va/bulk_load') do
      get BASE_QUERY_PATH + PDX_BBOX + '&type=health'
      expect(response).to be_success
      expect(response.body).to be_a(String)
      json = JSON.parse(response.body)
      expect(json['data'].length).to eq(3)
    end
  end

  it 'responds to GET #index with bbox and cemetery type' do
    VCR.use_cassette('facilities/va/bulk_load') do
      get BASE_QUERY_PATH + NY_BBOX + '&type=cemetery'
      expect(response).to be_success
      expect(response.body).to be_a(String)
      json = JSON.parse(response.body)
      expect(json['data'].length).to eq(5)
    end
  end

  it 'responds to GET #index with bbox and benefits type' do
    VCR.use_cassette('facilities/va/bulk_load') do
      get BASE_QUERY_PATH + NY_BBOX + '&type=benefits'
      expect(response).to be_success
      expect(response.body).to be_a(String)
      json = JSON.parse(response.body)
      expect(json['data'].length).to eq(12)
    end
  end

  it 'responds to GET #index with bbox and filter' do
    VCR.use_cassette('facilities/va/bulk_load') do
      get BASE_QUERY_PATH + NY_BBOX + '&type=benefits&services[]=DisabilityClaimAssistance'
      expect(response).to be_success
      expect(response.body).to be_a(String)
      json = JSON.parse(response.body)
      expect(json['data'].length).to eq(7)
    end
  end

  it 'returns zero results for point query' do
    VCR.use_cassette('facilities/va/point_bbox') do
      get BASE_QUERY_PATH + DEGEN_BBOX + '&type=benefits'
      expect(response).to be_success
      expect(response.body).to be_a(String)
      json = JSON.parse(response.body)
      expect(json['data'].length).to eq(0)
    end
  end

  it 'returns 400 for invalid type parameter' do
    VCR.use_cassette('facilities/va/bulk_load') do
      get BASE_QUERY_PATH + NY_BBOX + '&type=bogus'
      expect(response).to have_http_status(:bad_request)
    end
  end

  it 'returns 400 for query with services but no type' do
    VCR.use_cassette('facilities/va/bulk_load') do
      get BASE_QUERY_PATH + NY_BBOX + '&services[]=EyeCare'
      expect(response).to have_http_status(:bad_request)
    end
  end

  it 'returns 400 for health query with unknown service' do
    VCR.use_cassette('facilities/va/bulk_load') do
      get BASE_QUERY_PATH + NY_BBOX + '&type=health&services[]=OilChange'
      expect(response).to have_http_status(:bad_request)
    end
  end

  it 'returns 400 for benefits query with unknown service' do
    VCR.use_cassette('facilities/va/bulk_load') do
      get BASE_QUERY_PATH + NY_BBOX + '&type=benefits&services[]=Haircut'
      expect(response).to have_http_status(:bad_request)
    end
  end

  context 'with bad bbox param' do
    it 'returns 400 for nonsense bbox' do
      get '/v0/facilities/va?bbox[]=everywhere'
      expect(response).to have_http_status(:bad_request)
    end
    it 'returns 400 for non-array bbox' do
      get '/v0/facilities/va?bbox=-90,180,45,80'
      expect(response).to have_http_status(:bad_request)
    end
    it 'returns 400 for too many elements' do
      get '/v0/facilities/va?bbox[]=-45&bbox[]=-45&bbox[]=45&bbox=45&bbox=100'
      expect(response).to have_http_status(:bad_request)
    end
    it 'returns 400 for not enough elements' do
      get '/v0/facilities/va?bbox[]=-45&bbox[]=-45&bbox[]=45'
      expect(response).to have_http_status(:bad_request)
    end
    it 'returns 400 for non-numeric elements' do
      get '/v0/facilities/va?bbox[]=-45&bbox[]=-45&bbox[]=45&bbox=abc'
      expect(response).to have_http_status(:bad_request)
    end
  end
end
