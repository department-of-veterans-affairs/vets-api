# frozen_string_literal: true
require 'rails_helper'

RSpec.describe 'NCA GIS Integration', type: :request do
  it 'responds to GET #show' do
    VCR.use_cassette('facilities/cemetery/888') do
      get '/v0/facilities/cemetery/888'
      expect(response).to be_success
      expect(response.body).to be_a(String)
      json = JSON.parse(response.body)
      expect(json['data']['id']).to eq('888')
    end
  end

  it 'responds to GET #show non-existent' do
    VCR.use_cassette('facilities/cemetery/nonexistent') do
      get '/v0/facilities/cemetery/9999999'
      expect(response).to have_http_status(:not_found)
    end
  end

  it 'responds to GET #index with bbox' do
    VCR.use_cassette('facilities/cemetery/ny_bbox') do
      get '/v0/facilities/cemetery?bbox[]=-73.401&bbox[]=40.685&bbox[]=-77.36&bbox[]=43.03'
      expect(response).to be_success
      expect(response.body).to be_a(String)
      json = JSON.parse(response.body)
      expect(json['data'].length).to eq(5)
    end
  end
end
