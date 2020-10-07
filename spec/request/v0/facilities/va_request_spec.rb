# frozen_string_literal: true

require 'rails_helper'

vcr_options = {
  cassette_name: '/lighthouse/facilities',
  match_requests_on: %i[path query],
  allow_playback_repeats: true,
  record: :new_episodes
}

RSpec.describe 'VA Facilities Locator - PostGIS', type: :request, team: :facilities, vcr: vcr_options do
  include SchemaMatchers

  before do
    Flipper.enable(:facility_locator_pull_operating_status_from_lighthouse, true)
    Flipper.enable(:facility_locator_ppms_location_query, false)
  end

  BASE_QUERY_PATH = '/v0/facilities/va?'
  PDX_BBOX = 'bbox[]=-122.786758&bbox[]=45.451913&bbox[]=-122.440689&bbox[]=45.64'
  NY_BBOX = 'bbox[]=-73.401&bbox[]=40.685&bbox[]=-77.36&bbox[]=43.03'
  NOVA_BBOX = 'bbox[]=-79.512&bbox[]=37.55&bbox[]=-76.21&bbox[]=39.72'

  let(:ids_query) do
    ids = []
    setup_pdx.each do |facility|
      ids.push("#{facility.facility_type_prefix}_#{facility.unique_id}") if facility.facility_type != 'dod_health'
    end
    "ids=#{ids.join(',')}"
  end
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
    expect(response).to be_successful
    expect(response.body).to be_a(String)
    json = JSON.parse(response.body)
    expect(json['data']['id']).to eq('vha_648A4')
    expect(json).to include(
      {
        'data' => {
          'id' => 'vha_648A4',
          'type' => 'va_facilities',
          'attributes' => {
            'access' => {
              'health' => {
                'audiology' => {
                  'new' => 35.0, 'established' => 18.0
                },
                'optometry' => {
                  'new' => 38.0, 'established' => 22.0
                },
                'dermatology' => {
                  'new' => 4.0, 'established' => nil
                },
                'primary_care' => {
                  'new' => 34.0, 'established' => 5.0
                },
                'mental_health' => {
                  'new' => 12.0, 'established' => 3.0
                },
                'ophthalmology' => {
                  'new' => 1.0, 'established' => 4.0
                },
                'effective_date' => '2018-02-26'
              }
            },
            'address' => {
              'mailing' => {},
              'physical' => {
                'zip' => '98661-3753',
                'city' => 'Vancouver',
                'state' => 'WA',
                'address_1' => '1601 East 4th Plain Boulevard',
                'address_2' => nil,
                'address_3' => nil
              }
            },
            'classification' => 'VA Medical Center (VAMC)',
            'facility_type' => 'va_health_facility',
            'feedback' => {
              'health' => {
                'effective_date' => '2017-08-15', 'primary_care_urgent' => 0.8, 'primary_care_routine' => 0.84
              }
            },
            'hours' => {
              'monday' => '730AM-430PM',
              'tuesday' => '730AM-630PM',
              'wednesday' => '730AM-430PM',
              'thursday' => '730AM-430PM',
              'friday' => '730AM-430PM',
              'saturday' => '800AM-1000AM',
              'sunday' => '-'
            },
            'lat' => 45.6394162600001,
            'long' => -122.65528736,
            'name' => 'Portland VA Medical Center-Vancouver',
            'operating_status' => {
              'code' => 'NORMAL'
            },
            'phone' => {
              'fax' => '360-690-0864',
              'main' => '360-759-1901',
              'pharmacy' => '503-273-5183',
              'after_hours' => '360-696-4061',
              'patient_advocate' => '503-273-5308',
              'mental_health_clinic' => '503-273-5187',
              'enrollment_coordinator' => '503-273-5069'
            },
            'services' => {
              'health' => [{
                'sl1' => ['DentalServices'],
                'sl2' => []
              }, {
                'sl1' => ['MentalHealthCare'],
                'sl2' => []
              }, {
                'sl1' => ['PrimaryCare'],
                'sl2' => []
              }],
              'last_updated' => '2018-03-15'
            },
            'unique_id' => '648A4',
            'visn' => '20',
            'website' => 'http://www.portland.va.gov/locations/vancouver.asp'
          }
        }
      }
    )
  end

  it 'responds to GET #show for NCA prefix' do
    create :nca_888
    get '/v0/facilities/va/nca_888'
    expect(response).to be_successful
    expect(response.body).to be_a(String)
    json = JSON.parse(response.body)
    expect(json['data']['id']).to eq('nca_888')
  end

  it 'responds to GET #show for VBA prefix' do
    create :vba_314c
    get '/v0/facilities/va/vba_314c'
    expect(response).to be_successful
    expect(response.body).to be_a(String)
    json = JSON.parse(response.body)
    expect(json['data']['id']).to eq('vba_314c')
  end

  it 'responds to GET #show for VC prefix' do
    create :vc_0543V
    get '/v0/facilities/va/vc_0543V'
    expect(response).to be_successful
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
    expect(response).to be_successful
    expect(response.body).to be_a(String)
    json = JSON.parse(response.body)
    expect(json['data'].length).to eq(10)
  end

  it 'responds to GET #index with ids' do
    setup_pdx
    get BASE_QUERY_PATH + ids_query
    expect(response).to be_successful
    expect(response.body).to be_a(String)
    json = JSON.parse(response.body)
    expect(json['data'].length).to eq(10)
  end

  it 'responds to GET #index with bbox and health type' do
    setup_pdx
    get BASE_QUERY_PATH + PDX_BBOX + '&type=health'
    expect(response).to be_successful
    expect(response.body).to be_a(String)
    json = JSON.parse(response.body)
    expect(json['data'].length).to eq(3)
  end

  it 'responds to GET #index with bbox and cemetery type' do
    setup_ny_nca
    get BASE_QUERY_PATH + NY_BBOX + '&type=cemetery'
    expect(response).to be_successful
    expect(response.body).to be_a(String)
    json = JSON.parse(response.body)
    expect(json['data'].length).to eq(6)
  end

  it 'responds to GET #index with bbox and benefits type' do
    setup_ny_vba
    get BASE_QUERY_PATH + NY_BBOX + '&type=benefits'
    expect(response).to be_successful
    expect(response.body).to be_a(String)
    json = JSON.parse(response.body)
    expect(json['data'].length).to eq(10)
  end

  it 'responds to GET #index with bbox and filter' do
    setup_ny_vba
    get BASE_QUERY_PATH + NY_BBOX + '&type=benefits&services[]=DisabilityClaimAssistance'
    expect(response).to be_successful
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

  context 'Community Care (PPMS)' do
    around do |example|
      VCR.use_cassette('facilities/ppms/ppms', match_requests_on: %i[path query], allow_playback_repeats: true) do
        example.run
      end
    end

    let(:params) do
      {
        address: 'South Gilbert Road, Chandler, Arizona 85286, United States',
        bbox: ['-112.54', '32.53', '-111.04', '34.03']
      }
    end

    it 'responds to GET #index with bbox, address, and ccp type' do
      VCR.use_cassette(
        'facilities/ppms/ppms_new_query',
        match_requests_on: %i[path query],
        allow_playback_repeats: true
      ) do
        get '/v0/facilities/va', params: params.merge('type' => 'cc_provider', 'services' => ['213E00000X'])
        expect(response).to be_successful
        expect(response.body).to be_a(String)
        json = JSON.parse(response.body)
        expect(json['data'].length).to eq(1)
        provider = json['data'][0]
        expect(provider['attributes']['address']['city']).to eq('Chandler')
        expect(provider['attributes']['phone']).to eq('4809241552')
        expect(provider['attributes']['caresite_phone']).to eq('4807057300')
      end
    end

    it 'responds to GET #index with success even if no providers are found' do
      VCR.use_cassette(
        'facilities/ppms/ppms_empty_search',
        match_requests_on: [:method],
        allow_playback_repeats: true
      ) do
        get BASE_QUERY_PATH + PDX_BBOX + '&type=cc_provider&address=97089'
        expect(response).to be_successful
        expect(response.body).to be_a(String)
        json = JSON.parse(response.body)
        expect(json['data'].length).to eq(0)
      end
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

  context 'health services' do
    it 'includes the appropriate services from wait time data' do
      setup_pdx
      get '/v0/facilities/va/vha_648'
      expect(response).to be_successful
      expect(response.body).to be_a(String)
      services = JSON.parse(response.body)['data']['attributes']['services']
      expect(services['health']).to include('sl1' => ['EmergencyCare'], 'sl2' => [])
      expect(services['health']).to include('sl1' => ['UrgentCare'], 'sl2' => [])
      expect(services['health']).to include('sl1' => ['Audiology'], 'sl2' => [])
      expect(services['health']).to include('sl1' => ['Optometry'], 'sl2' => [])
    end

    it 'does not include services that have no wait_time_data' do
      setup_pdx
      get '/v0/facilities/va/vha_648A4'
      expect(response).to be_successful
      expect(response.body).to be_a(String)
      services = JSON.parse(response.body)['data']['attributes']['services']
      expect(services['health']).not_to include('sl1' => ['EmergencyCare'], 'sl2' => [])
      expect(services['health']).not_to include('sl1' => ['UrgentCare'], 'sl2' => [])
      expect(services['health']).not_to include('sl1' => ['Audiology'], 'sl2' => [])
      expect(services['health']).not_to include('sl1' => ['Optometry'], 'sl2' => [])
    end
  end

  describe '/v0/facilities/suggested/:facility_type' do
    before { setup_pdx }

    context 'when facilities are found' do
      let(:facilites) { JSON.parse(response.body)['data'] }
      let(:inflection_header) { { 'X-Key-Inflection' => 'camel' } }

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
        it 'returns 3 facilities when camel-inflected' do
          get '/v0/facilities/suggested?name_part=por&type[]=health', headers: inflection_header
          expect(response).to have_http_status(:ok)
          expect(response).to match_camelized_response_schema('suggested_facilities')
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
        it 'returns 2 facilities when camel-inflected' do
          get '/v0/facilities/suggested?name_part=por&type[]=dod_health', headers: inflection_header
          expect(response).to have_http_status(:ok)
          expect(response).to match_camelized_response_schema('suggested_facilities')
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
        it 'returns 5 facilities when camel-inflected' do
          get '/v0/facilities/suggested?name_part=por&type[]=health&type[]=dod_health', headers: inflection_header
          expect(response).to have_http_status(:ok)
          expect(response).to match_camelized_response_schema('suggested_facilities')
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
        it do
          get '/v0/facilities/suggested?name_part=por&type[]=foo'
          expect(response).to have_http_status(:bad_request)
          expect(error_detail).to eq('"["foo"]" is not a valid value for "type"')
        end
      end

      context 'with one valid and one invalid type' do
        it do
          get '/v0/facilities/suggested?name_part=por&type[]=foo&type[]=health'
          expect(response).to have_http_status(:bad_request)
          expect(error_detail).to eq('"["foo", "health"]" is not a valid value for "type"')
        end
      end

      context 'when type is missing' do
        it do
          get '/v0/facilities/suggested?name_part=xxx'
          expect(response).to have_http_status(:bad_request)
          expect(error_detail).to eq('The required parameter "type", is missing')
        end
      end

      context 'when name_part is missing' do
        it do
          get '/v0/facilities/suggested?&type[]=health'
          expect(response).to have_http_status(:bad_request)
          expect(error_detail).to eq('The required parameter "name_part", is missing')
        end
      end
    end
  end
end
