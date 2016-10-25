# frozen_string_literal: true
require 'rails_helper'

RSpec.describe 'VA GIS Integration', type: :request do
  before(:all) do
    VCR.use_cassette('facilities/va/warmup') do
      # Warm up client library initial request so it doesn't need to appear in all cassettes
      get '/v0/facilities/va/?bbox[]=-122&bbox[]=45&bbox[]=-122&bbox[]=45'
    end
  end

  it 'responds to GET #show for VHA prefix' do
    VCR.use_cassette('facilities/va/vha_648A4') do
      get '/v0/facilities/va/vha_648A4'
      expect(response).to be_success
      expect(response.body).to be_a(String)
      json = JSON.parse(response.body)
      expect(json['data']['id']).to eq('vha_648A4')
    end
  end

  it 'responds to GET #show for NCA prefix' do
    VCR.use_cassette('facilities/va/nca_888') do
      get '/v0/facilities/va/nca_888'
      expect(response).to be_success
      expect(response.body).to be_a(String)
      json = JSON.parse(response.body)
      expect(json['data']['id']).to eq('nca_888')
    end
  end

  it 'responds to GET #show without prefix' do
    VCR.use_cassette('facilities/va/nonexistent_noprefix') do
      get '/v0/facilities/va/684A4'
      expect(response).to have_http_status(:not_found)
    end
  end

  it 'responds to GET #show non-existent' do
    VCR.use_cassette('facilities/va/nonexistent_cemetery') do
      get '/v0/facilities/va/nca_9999999'
      expect(response).to have_http_status(:not_found)
    end
  end

  it 'responds to GET #index with bbox' do
    VCR.use_cassette('facilities/va/pdx_bbox') do
      get '/v0/facilities/va?bbox[]=-122.440689&bbox[]=45.451913&bbox[]=-122.786758&bbox[]=45.64'
      expect(response).to be_success
      expect(response.body).to be_a(String)
      json = JSON.parse(response.body)
      expect(json['data'].length).to eq(4)
    end
  end

  it 'responds to GET #index with bbox and health type' do
    VCR.use_cassette('facilities/va/pdx_bbox') do
      get '/v0/facilities/va?type=health&bbox[]=-122.440689&bbox[]=45.451913&bbox[]=-122.786758&bbox[]=45.64'
      expect(response).to be_success
      expect(response.body).to be_a(String)
      json = JSON.parse(response.body)
      expect(json['data'].length).to eq(3)
    end
  end

  it 'responds to GET #index with bbox and cemetery type' do
    VCR.use_cassette('facilities/va/ny_bbox') do
      get '/v0/facilities/va?type=cemetery&bbox[]=-73.401&bbox[]=40.685&bbox[]=-77.36&bbox[]=43.03'
      expect(response).to be_success
      expect(response.body).to be_a(String)
      json = JSON.parse(response.body)
      expect(json['data'].length).to eq(5)
    end
  end

  it 'returns 400 for invalid type parameter' do
    VCR.use_cassette('facilities/va/bad_type_param') do
      get '/v0/facilities/va?type=bogus&bbox[]=-73.401&bbox[]=40.685&bbox[]=-77.36&bbox[]=43.03'
      expect(response).to have_http_status(:bad_request)
    end
  end

  it 'returns 400 for query with services but no type' do
    VCR.use_cassette('facilities/va/service_type_params') do
      get '/v0/facilities/va?services[]=EyeCare&bbox[]=-73.401&bbox[]=40.685&bbox[]=-77.36&bbox[]=43.03'
      expect(response).to have_http_status(:bad_request)
    end
  end

  it 'returns 400 for query with unknown service' do
    VCR.use_cassette('facilities/va/service_type_params') do
      get '/v0/facilities/va?type=health&services[]=OilChange&bbox[]=-73.401&bbox[]=40.685&bbox[]=-77.36&bbox[]=43.03'
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
