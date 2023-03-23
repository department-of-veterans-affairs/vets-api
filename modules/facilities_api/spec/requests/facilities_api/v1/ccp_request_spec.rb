# frozen_string_literal: true

require 'rails_helper'

vcr_options = {
  cassette_name: 'facilities/ppms/ppms',
  match_requests_on: %i[path query],
  allow_playback_repeats: true
}

RSpec.describe 'FacilitiesApi::V1::Ccp', type: :request, team: :facilities, vcr: vcr_options do
  before(:all) do
    get facilities_api.v1_ccp_index_url
  end

  let(:sha256) { 'bd2b84cc5c0aa3676090eacde32e99c7d668388e5fc5440e3c582aef419fc398' }

  let(:params) do
    {
      lat: 40.415217,
      long: -74.057114,
      radius: 200,
      type: 'provider',
      specialties: ['213E00000X']
    }
  end

  let(:place_of_service) do
    {
      'id' => '1a2ec66b370936eccc980db2fcf4b094fc61a5329aea49744d538f6a9bab2569',
      'type' => 'provider',
      'attributes' =>
       {
         'accNewPatients' => 'false',
         'address' => {
           'street' => '2 BAYSHORE PLZ',
           'city' => 'ATLANTIC HIGHLANDS',
           'state' => 'NJ',
           'zip' => '07716'
         },
         'caresitePhone' => '732-291-2900',
         'email' => nil,
         'fax' => nil,
         'gender' => 'NotSpecified',
         'lat' => 40.409114,
         'long' => -74.041849,
         'name' => 'BAYSHORE PHARMACY',
         'phone' => nil,
         'posCodes' => '17',
         'prefContact' => nil,
         'uniqueId' => '1225028293'
       }
    }
  end

  describe '#index' do
    context 'Empty Results', vcr: vcr_options.merge(
      cassette_name: 'facilities/ppms/ppms_empty_search',
      match_requests_on: [:method]
    ) do
      it 'responds to GET #index with success even if no providers are found' do
        get('/facilities_api/v1/ccp', params:)

        expect(response).to be_successful
      end
    end

    context 'type=provider' do
      context 'Missing specialties param' do
        let(:params) do
          {
            lat: 40.415217,
            long: -74.057114,
            radius: 200,
            type: 'provider'
          }
        end

        it 'requires a specialty code' do
          get('/facilities_api/v1/ccp', params:)

          bod = JSON.parse(response.body)

          expect(bod).to include(
            'errors' => [
              {
                'title' => 'Missing parameter',
                'detail' => 'The required parameter "specialties", is missing',
                'code' => '108',
                'status' => '400'
              }
            ]
          )

          expect(response).not_to be_successful
        end
      end

      context 'specialties=261QU0200X' do
        let(:params) do
          {
            lat: 40.415217,
            long: -74.057114,
            radius: 200,
            type: 'provider',
            specialties: ['261QU0200X']
          }
        end

        it 'returns a results from the pos_locator' do
          get('/facilities_api/v1/ccp', params:)

          bod = JSON.parse(response.body)

          expect(bod['data']).to include(place_of_service)

          expect(response).to be_successful
        end
      end

      it "sends a 'facilities.ppms.v1.request.faraday' notification to any subscribers listening" do
        allow(StatsD).to receive(:measure)

        expect(StatsD).to receive(:measure).with(
          'facilities.ppms.facility_service_locator',
          kind_of(Numeric),
          hash_including(
            tags: [
              'facilities.ppms',
              'facilities.ppms.radius:200',
              'facilities.ppms.results:10'
            ]
          )
        )

        expect do
          get '/facilities_api/v1/ccp', params:
        end.to instrument('facilities.ppms.v1.request.faraday')
      end

      [
        [1, 20],
        [2, 20],
        [3, 20]
      ].each do |(page, per_page, _total_entries)|
        it "paginates ppms responses (page: #{page}, per_page: #{per_page}" do
          params_with_pagination = params.merge(
            page: page.to_s,
            per_page: per_page.to_s
          )

          get '/facilities_api/v1/ccp', params: params_with_pagination
          bod = JSON.parse(response.body)

          prev_page = page == 1 ? nil : page - 1
          expect(bod['meta']).to include(
            'pagination' => {
              'current_page' => page,
              'prev_page' => prev_page,
              'next_page' => page + 1,
              'total_pages' => 120,
              'total_entries' => 2394
            }
          )
        end
      end

      it 'returns a results from the provider_locator' do
        get('/facilities_api/v1/ccp', params:)

        bod = JSON.parse(response.body)
        expect(bod['data']).to include(
          {
            'id' => '6d4644e7db7491635849b23e20078f74cfcd2d0aeee6a77aca921f5540d03f33',
            'type' => 'provider',
            'attributes' => {
              'accNewPatients' => 'true',
              'address' => {
                'street' => '176 RIVERSIDE AVE',
                'city' => 'RED BANK',
                'state' => 'NJ',
                'zip' => '07701-1063'
              },
              'caresitePhone' => '732-219-6625',
              'email' => nil,
              'fax' => nil,
              'gender' => 'Female',
              'lat' => 40.35396,
              'long' => -74.07492,
              'name' => 'GESUALDI, AMY',
              'phone' => nil,
              'posCodes' => nil,
              'prefContact' => nil,
              'uniqueId' => '1154383230'
            }
          }
        )

        expect(response).to be_successful
      end
    end

    context 'type=pharmacy' do
      let(:params) do
        {
          lat: 40.415217,
          long: -74.057114,
          radius: 200,
          type: 'pharmacy'
        }
      end

      it 'returns results from the pos_locator' do
        get('/facilities_api/v1/ccp', params:)

        bod = JSON.parse(response.body)

        expect(bod['data'][0]).to match(
          {
            'id' => '1a2ec66b370936eccc980db2fcf4b094fc61a5329aea49744d538f6a9bab2569',
            'type' => 'provider',
            'attributes' => {
              'accNewPatients' => 'false',
              'address' => {
                'street' => '2 BAYSHORE PLZ',
                'city' => 'ATLANTIC HIGHLANDS',
                'state' => 'NJ',
                'zip' => '07716'
              },
              'caresitePhone' => '732-291-2900',
              'email' => nil,
              'fax' => nil,
              'gender' => 'NotSpecified',
              'lat' => 40.409114,
              'long' => -74.041849,
              'name' => 'BAYSHORE PHARMACY',
              'phone' => nil,
              'posCodes' => nil,
              'prefContact' => nil,
              'uniqueId' => '1225028293'
            }
          }
        )

        expect(response).to be_successful
      end
    end

    context 'type=urgent_care' do
      let(:params) do
        {
          lat: 40.415217,
          long: -74.057114,
          radius: 200,
          type: 'urgent_care'
        }
      end

      it 'returns results from the pos_locator' do
        get('/facilities_api/v1/ccp', params:)

        bod = JSON.parse(response.body)

        expect(bod['data']).to include(place_of_service)

        expect(response).to be_successful
      end
    end
  end

  describe '#provider' do
    context 'Missing specialties param' do
      let(:params) do
        {
          lat: 40.415217,
          long: -74.057114,
          radius: 200
        }
      end

      it 'requires a specialty code' do
        get('/facilities_api/v1/ccp/provider', params:)

        bod = JSON.parse(response.body)

        expect(bod).to include(
          'errors' => [
            {
              'title' => 'Missing parameter',
              'detail' => 'The required parameter "specialties", is missing',
              'code' => '108',
              'status' => '400'
            }
          ]
        )

        expect(response).not_to be_successful
      end
    end

    context 'specialties=261QU0200X' do
      let(:params) do
        {
          lat: 40.415217,
          long: -74.057114,
          radius: 200,
          specialties: ['261QU0200X']
        }
      end

      it 'returns a results from the pos_locator' do
        get('/facilities_api/v1/ccp/provider', params:)

        bod = JSON.parse(response.body)

        expect(bod['data']).to include(place_of_service)

        expect(response).to be_successful
      end
    end

    it 'returns a results from the provider_locator' do
      get('/facilities_api/v1/ccp/provider', params:)

      bod = JSON.parse(response.body)
      expect(bod['data']).to include(
        {
          'id' => '6d4644e7db7491635849b23e20078f74cfcd2d0aeee6a77aca921f5540d03f33',
          'type' => 'provider',
          'attributes' => {
            'accNewPatients' => 'true',
            'address' => {
              'street' => '176 RIVERSIDE AVE',
              'city' => 'RED BANK',
              'state' => 'NJ',
              'zip' => '07701-1063'
            },
            'caresitePhone' => '732-219-6625',
            'email' => nil,
            'fax' => nil,
            'gender' => 'Female',
            'lat' => 40.35396,
            'long' => -74.07492,
            'name' => 'GESUALDI, AMY',
            'phone' => nil,
            'posCodes' => nil,
            'prefContact' => nil,
            'uniqueId' => '1154383230'
          }
        }
      )

      expect(response).to be_successful
    end
  end

  describe '#pharmacy' do
    let(:params) do
      {
        lat: 40.415217,
        long: -74.057114,
        radius: 200
      }
    end

    it 'returns results from the pos_locator' do
      get('/facilities_api/v1/ccp/pharmacy', params:)

      bod = JSON.parse(response.body)

      expect(bod['data'][0]).to match(
        {
          'id' => '1a2ec66b370936eccc980db2fcf4b094fc61a5329aea49744d538f6a9bab2569',
          'type' => 'provider',
          'attributes' => {
            'accNewPatients' => 'false',
            'address' => {
              'street' => '2 BAYSHORE PLZ',
              'city' => 'ATLANTIC HIGHLANDS',
              'state' => 'NJ',
              'zip' => '07716'
            },
            'caresitePhone' => '732-291-2900',
            'email' => nil,
            'fax' => nil,
            'gender' => 'NotSpecified',
            'lat' => 40.409114,
            'long' => -74.041849,
            'name' => 'BAYSHORE PHARMACY',
            'phone' => nil,
            'posCodes' => nil,
            'prefContact' => nil,
            'uniqueId' => '1225028293'
          }
        }
      )

      expect(response).to be_successful
    end
  end

  describe '#urgent_care' do
    let(:params) do
      {
        lat: 40.415217,
        long: -74.057114,
        radius: 200
      }
    end

    it 'returns results from the pos_locator' do
      get('/facilities_api/v1/ccp/urgent_care', params:)

      bod = JSON.parse(response.body)

      expect(bod['data']).to include(place_of_service)

      expect(response).to be_successful
    end
  end

  describe '#specialties', vcr: vcr_options.merge(cassette_name: 'facilities/ppms/ppms_specialties') do
    it 'returns a list of available specializations' do
      get '/facilities_api/v1/ccp/specialties'

      bod = JSON.parse(response.body)

      expect(bod['data'][0..1]).to match(
        [
          {
            'id' => '101Y00000X',
            'type' => 'specialty',
            'attributes' => {
              'classification' => 'Counselor',
              'grouping' => 'Behavioral Health & Social Service Providers',
              'name' => 'Counselor',
              'specialization' => nil,
              'specialtyCode' => '101Y00000X',
              'specialtyDescription' => 'A provider who is trained and educated in the performance of behavior ' \
                                        'health services through interpersonal communications and analysis. ' \
                                        'Training and education at the specialty level usually requires a ' \
                                        'master\'s degree and clinical experience and supervision for licensure ' \
                                        'or certification.'
            }
          },
          {
            'id' => '101YA0400X',
            'type' => 'specialty',
            'attributes' => {
              'classification' => 'Counselor',
              'grouping' => 'Behavioral Health & Social Service Providers',
              'name' => 'Counselor - Addiction (Substance Use Disorder)',
              'specialization' => 'Addiction (Substance Use Disorder)',
              'specialtyCode' => '101YA0400X',
              'specialtyDescription' => 'Definition to come...'
            }
          }
        ]
      )
    end
  end
end
