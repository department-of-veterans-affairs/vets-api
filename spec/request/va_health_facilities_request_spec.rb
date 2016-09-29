# frozen_string_literal: true
require 'rails_helper'

RSpec.describe 'VHA GIS Integration', type: :request do
  it 'responds to GET #show' do
    VCR.use_cassette('facilities/va/648A4') do
      get '/v0/facilities/va/648A4'
      expect(response).to be_success
      expect(response.body).to be_a(String)
      json = JSON.parse(response.body)
      expect(json['data']['id']).to eq('648A4')
    end
  end

  it 'responds to GET #show non-existent' do
    VCR.use_cassette('facilities/va/nonexistent') do
      get '/v0/facilities/va/9999999'
      expect(response).to have_http_status(:not_found)
    end
  end

  it 'responds to GET #index with bbox' do
    VCR.use_cassette('facilities/va/pdx_bbox') do
      get '/v0/facilities/va?bbox[]=-122.440689&bbox[]=45.451913&bbox[]=-122.786758&bbox[]=45.64'
      expect(response).to be_success
      expect(response.body).to be_a(String)
      json = JSON.parse(response.body)
      expect(json['data'].length).to eq(3)
    end
  end

  it 'responds to GET #index with bbox and services' do
    VCR.use_cassette('facilities/va/pdx_bbox_filtered') do
      get '/v0/facilities/va?bbox[]=-122.440689&bbox[]=45.451913&bbox[]=-122.786758&bbox[]=45.64&services[]=EyeCare'
      expect(response).to be_success
      expect(response.body).to be_a(String)
      json = JSON.parse(response.body)
      expect(json['data'].length).to eq(2)
    end
  end
end
