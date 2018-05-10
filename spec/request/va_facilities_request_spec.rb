# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'VA GIS Integration', type: :request do
  include SchemaMatchers

  BASE_QUERY_PATH = '/v0/facilities/va?'
  PDX_BBOX = 'bbox[]=-122.440689&bbox[]=45.451913&bbox[]=-122.786758&bbox[]=45.64'
  NY_BBOX = 'bbox[]=-73.401&bbox[]=40.685&bbox[]=-77.36&bbox[]=43.03'

  let(:setup_pdx) do
    %w[
      vc_0617V nca_907 vha_648 vha_648A4 vha_648GI vba_348
      vba_348a vba_348d vba_348e vba_348h dod_001 dod_002
    ].map { |id| create id }
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
    get '/v0/facilities/va/vha_648A4'
    expect(response).to be_success
    expect(response.body).to be_a(String)
    json = JSON.parse(response.body)
    expect(json['data']['id']).to eq('vha_648A4')
  end

  it 'responds to GET #show for NCA prefix' do
    create :nca_888
    get '/v0/facilities/va/nca_888'
    expect(response).to be_success
    expect(response.body).to be_a(String)
    json = JSON.parse(response.body)
    expect(json['data']['id']).to eq('nca_888')
  end

  it 'responds to GET #show for VBA prefix' do
    create :vba_314c
    get '/v0/facilities/va/vba_314c'
    expect(response).to be_success
    expect(response.body).to be_a(String)
    json = JSON.parse(response.body)
    expect(json['data']['id']).to eq('vba_314c')
  end

  it 'responds to GET #show for VC prefix' do
    create :vc_0543V
    get '/v0/facilities/va/vc_0543V'
    expect(response).to be_success
    expect(response.body).to be_a(String)
    json = JSON.parse(response.body)
    expect(json['data']['id']).to eq('vc_0543V')
  end

  it 'responds to GET #show without prefix' do
    get '/v0/facilities/va/684A4'
    expect(response).to have_http_status(:not_found)
  end

  it 'responds to GET #show non-existent' do
    get '/v0/facilities/va/nca_9999999'
    expect(response).to have_http_status(:not_found)
  end

  it 'responds to GET #index with bbox' do
    setup_pdx
    get BASE_QUERY_PATH + PDX_BBOX
    expect(response).to be_success
    expect(response.body).to be_a(String)
    json = JSON.parse(response.body)
    expect(json['data'].length).to eq(10)
  end

  it 'responds to GET #index with bbox and health type' do
    setup_pdx
    get BASE_QUERY_PATH + PDX_BBOX + '&type=health'
    expect(response).to be_success
    expect(response.body).to be_a(String)
    json = JSON.parse(response.body)
    expect(json['data'].length).to eq(3)
  end

  it 'responds to GET #index with bbox and cemetery type' do
    setup_ny_nca
    get BASE_QUERY_PATH + NY_BBOX + '&type=cemetery'
    expect(response).to be_success
    expect(response.body).to be_a(String)
    json = JSON.parse(response.body)
    expect(json['data'].length).to eq(6)
  end

  it 'responds to GET #index with bbox and benefits type' do
    setup_ny_vba
    get BASE_QUERY_PATH + NY_BBOX + '&type=benefits'
    expect(response).to be_success
    expect(response.body).to be_a(String)
    json = JSON.parse(response.body)
    expect(json['data'].length).to eq(12)
  end

  it 'responds to GET #index with bbox and filter' do
    setup_ny_vba
    get BASE_QUERY_PATH + NY_BBOX + '&type=benefits&services[]=DisabilityClaimAssistance'
    expect(response).to be_success
    expect(response.body).to be_a(String)
    json = JSON.parse(response.body)
    expect(json['data'].length).to eq(7)
  end

  it 'returns 400 for invalid type parameter' do
    get BASE_QUERY_PATH + NY_BBOX + '&type=bogus'
    expect(response).to have_http_status(:bad_request)
  end

  it 'returns 400 for query with services but no type' do
    get BASE_QUERY_PATH + NY_BBOX + '&services[]=EyeCare'
    expect(response).to have_http_status(:bad_request)
  end

  it 'returns 400 for health query with unknown service' do
    get BASE_QUERY_PATH + NY_BBOX + '&type=health&services[]=OilChange'
    expect(response).to have_http_status(:bad_request)
  end

  it 'returns 400 for benefits query with unknown service' do
    get BASE_QUERY_PATH + NY_BBOX + '&type=benefits&services[]=Haircut'
    expect(response).to have_http_status(:bad_request)
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

  context 'health services' do
    it 'includes emergency_care and urgent_care when appropriate' do
      setup_pdx
      get '/v0/facilities/va/vha_648'
      expect(response).to be_success
      expect(response.body).to be_a(String)
      services = JSON.parse(response.body)['data']['attributes']['services']
      expect(services['health']).to include('sl1' => ['EmergencyCare'], 'sl2' => [])
      expect(services['health']).to include('sl1' => ['UrgentCare'], 'sl2' => [])
    end

    it 'does not include emergency_care and urgent_care when appropriate' do
      setup_pdx
      get '/v0/facilities/va/vha_648A4'
      expect(response).to be_success
      expect(response.body).to be_a(String)
      services = JSON.parse(response.body)['data']['attributes']['services']
      expect(services['health']).not_to include('sl1' => ['EmergencyCare'], 'sl2' => [])
      expect(services['health']).not_to include('sl1' => ['UrgentCare'], 'sl2' => [])
    end
  end

  describe '/v0/facilities/suggested/:facility_type' do
    before(:each) { setup_pdx }

    context 'when facilities are found' do
      let(:facilites) { JSON.parse(response.body)['data'] }

      context 'with a health facility type' do
        it 'returns 3 facilities' do
          get '/v0/facilities/suggested?name_part=por&type[]=health'
          expect(response).to have_http_status(:ok)
          expect(response).to match_response_schema('suggested_facilities')
          expect(facilites.count).to eq(3)
          expect(facilites.map { |f| f['attributes']['name'] }).to match_array(
            ['Portland VA Medical Center', 'Portland VA Medical Center-Vancouver', 'Portland VA Clinic']
          )
        end
      end

      context 'with a dod facility type' do
        it 'returns 2 facilities' do
          get '/v0/facilities/suggested?name_part=por&type[]=dod_health'
          expect(response).to have_http_status(:ok)
          expect(response).to match_response_schema('suggested_facilities')
          expect(facilites.count).to eq(2)
          expect(facilites.map { |f| f['attributes']['name'] }).to match_array(
            ['Portland Army Medical Center', 'Portland Naval Hospital']
          )
        end
      end

      context 'with multiple facility types' do
        it 'returns 5 facilities' do
          get '/v0/facilities/suggested?name_part=por&type[]=health&type[]=dod_health'
          expect(response).to have_http_status(:ok)
          expect(response).to match_response_schema('suggested_facilities')
          expect(facilites.count).to eq(5)
          expect(facilites.map { |f| f['attributes']['name'] }).to match_array(
            [
              'Portland VA Medical Center',
              'Portland VA Medical Center-Vancouver',
              'Portland VA Clinic',
              'Portland Army Medical Center',
              'Portland Naval Hospital'
            ]
          )
        end
      end

      context 'when facilites are not found' do
        it 'returns an empty array' do
          get '/v0/facilities/suggested?name_part=xxx&type[]=health'
          expect(response).to have_http_status(:ok)
          expect(facilites.count).to eq(0)
        end
      end
    end

    context 'with invalid input' do
      let(:error_detail) { JSON.parse(response.body)['errors'].first['detail'] }

      context 'with an invalid type' do
        it '' do
          get '/v0/facilities/suggested?name_part=por&type[]=foo'
          expect(response).to have_http_status(:bad_request)
          expect(error_detail).to eq('"["foo"]" is not a valid value for "type"')
        end
      end

      context 'with one valid and one invalid type' do
        it '' do
          get '/v0/facilities/suggested?name_part=por&type[]=foo&type[]=health'
          expect(response).to have_http_status(:bad_request)
          expect(error_detail).to eq('"["foo", "health"]" is not a valid value for "type"')
        end
      end

      context 'when type is missing' do
        it '' do
          get '/v0/facilities/suggested?name_part=xxx'
          expect(response).to have_http_status(:bad_request)
          expect(error_detail).to eq('The required parameter "type", is missing')
        end
      end

      context 'when name_part is missing' do
        it '' do
          get '/v0/facilities/suggested?&type[]=health'
          expect(response).to have_http_status(:bad_request)
          expect(error_detail).to eq('The required parameter "name_part", is missing')
        end
      end
    end
  end
end
