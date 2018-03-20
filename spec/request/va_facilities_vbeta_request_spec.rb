# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'VA GIS Integration beta', type: :request do
  BASE_QUERY_BETA_PATH = '/vbeta/facilities/va?'
  PDX_BBOX_BETA = 'bbox[]=-122.440689&bbox[]=45.451913&bbox[]=-122.786758&bbox[]=45.64'
  NY_BBOX_BETA = 'bbox[]=-73.401&bbox[]=40.685&bbox[]=-77.36&bbox[]=43.03'

  let(:setup_pdx) do
    %w[vc_0617V nca_907 vha_648 vha_648A4 vha_648GI vba_348 vba_348a vba_348d vba_348e vba_348h].map { |id| create id }
  end
  let(:setup_ny_nca) do
    %w[nca_824 nca_088 nca_808 nca_803 nca_917 nca_815].map { |id| create id }
  end
  let(:setup_ny_vba) do
    ids = %w[vba_310e vba_306f vba_306a vba_306d vba_306g vba_309 vba_306 vba_306b vba_306e vba_306h vba_306i vba_306c]
    ids.map { |id| create id }
  end
  it 'responds to GET #show for VHA prefix' do
    create :vha_648A4
    get '/vbeta/facilities/va/vha_648A4'
    expect(response).to be_success
    expect(response.body).to be_a(String)
    json = JSON.parse(response.body)
    expect(json['data']['id']).to eq('vha_648A4')
  end

  it 'responds to GET #show for NCA prefix' do
    create :nca_888
    get '/vbeta/facilities/va/nca_888'
    expect(response).to be_success
    expect(response.body).to be_a(String)
    json = JSON.parse(response.body)
    expect(json['data']['id']).to eq('nca_888')
  end

  it 'responds to GET #show for VBA prefix' do
    create :vba_314c
    get '/vbeta/facilities/va/vba_314c'
    expect(response).to be_success
    expect(response.body).to be_a(String)
    json = JSON.parse(response.body)
    expect(json['data']['id']).to eq('vba_314c')
  end

  it 'responds to GET #show for VC prefix' do
    create :vc_0543V
    get '/vbeta/facilities/va/vc_0543V'
    expect(response).to be_success
    expect(response.body).to be_a(String)
    json = JSON.parse(response.body)
    expect(json['data']['id']).to eq('vc_0543V')
  end

  it 'responds to GET #show without prefix' do
    get '/vbeta/facilities/va/684A4'
    expect(response).to have_http_status(:not_found)
  end

  it 'responds to GET #show non-existent' do
    get '/vbeta/facilities/va/nca_9999999'
    expect(response).to have_http_status(:not_found)
  end

  it 'responds to GET #index with bbox' do
    setup_pdx
    get BASE_QUERY_BETA_PATH + PDX_BBOX_BETA
    expect(response).to be_success
    expect(response.body).to be_a(String)
    json = JSON.parse(response.body)
    expect(json['data'].length).to eq(10)
  end

  it 'responds to GET #index with bbox and health type' do
    setup_pdx
    get BASE_QUERY_BETA_PATH + PDX_BBOX_BETA + '&type=health'
    expect(response).to be_success
    expect(response.body).to be_a(String)
    json = JSON.parse(response.body)
    expect(json['data'].length).to eq(3)
  end

  it 'responds to GET #index with bbox and cemetery type' do
    setup_ny_nca
    get BASE_QUERY_BETA_PATH + NY_BBOX_BETA + '&type=cemetery'
    expect(response).to be_success
    expect(response.body).to be_a(String)
    json = JSON.parse(response.body)
    expect(json['data'].length).to eq(6)
  end

  it 'responds to GET #index with bbox and benefits type' do
    setup_ny_vba
    get BASE_QUERY_BETA_PATH + NY_BBOX_BETA + '&type=benefits'
    expect(response).to be_success
    expect(response.body).to be_a(String)
    json = JSON.parse(response.body)
    expect(json['data'].length).to eq(12)
  end

  it 'responds to GET #index with bbox and filter' do
    setup_ny_vba
    get BASE_QUERY_BETA_PATH + NY_BBOX_BETA + '&type=benefits&services[]=DisabilityClaimAssistance'
    expect(response).to be_success
    expect(response.body).to be_a(String)
    json = JSON.parse(response.body)
    expect(json['data'].length).to eq(7)
  end

  it 'gets #all' do
    setup_pdx
    get '/vbeta/facilities/va/all'
    expect(response).to be_success
    expect(response.body).to be_a(String)
    json = JSON.parse(response.body)
    expect(json.length).to eq(10)
  end

  it 'returns 400 for invalid type parameter' do
    get BASE_QUERY_BETA_PATH + NY_BBOX_BETA + '&type=bogus'
    expect(response).to have_http_status(:bad_request)
  end

  it 'returns 400 for query with services but no type' do
    get BASE_QUERY_BETA_PATH + NY_BBOX_BETA + '&services[]=EyeCare'
    expect(response).to have_http_status(:bad_request)
  end

  it 'returns 400 for health query with unknown service' do
    get BASE_QUERY_BETA_PATH + NY_BBOX_BETA + '&type=health&services[]=OilChange'
    expect(response).to have_http_status(:bad_request)
  end

  it 'returns 400 for benefits query with unknown service' do
    get BASE_QUERY_BETA_PATH + NY_BBOX_BETA + '&type=benefits&services[]=Haircut'
    expect(response).to have_http_status(:bad_request)
  end

  context 'with bad bbox param' do
    it 'returns 400 for nonsense bbox' do
      get '/vbeta/facilities/va?bbox[]=everywhere'
      expect(response).to have_http_status(:bad_request)
    end
    it 'returns 400 for non-array bbox' do
      get '/vbeta/facilities/va?bbox=-90,180,45,80'
      expect(response).to have_http_status(:bad_request)
    end
    it 'returns 400 for too many elements' do
      get '/vbeta/facilities/va?bbox[]=-45&bbox[]=-45&bbox[]=45&bbox=45&bbox=100'
      expect(response).to have_http_status(:bad_request)
    end
    it 'returns 400 for not enough elements' do
      get '/vbeta/facilities/va?bbox[]=-45&bbox[]=-45&bbox[]=45'
      expect(response).to have_http_status(:bad_request)
    end
    it 'returns 400 for non-numeric elements' do
      get '/vbeta/facilities/va?bbox[]=-45&bbox[]=-45&bbox[]=45&bbox=abc'
      expect(response).to have_http_status(:bad_request)
    end
  end
end
