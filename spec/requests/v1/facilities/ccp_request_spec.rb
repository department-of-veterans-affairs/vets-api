# frozen_string_literal: true

require 'rails_helper'
require 'facilities/ppms/v1/client'

vcr_options = {
  cassette_name: 'facilities/ppms/ppms_old',
  match_requests_on: %i[path query],
  allow_playback_repeats: true
}

RSpec.describe 'Community Care Providers', team: :facilities, vcr: vcr_options do
  before do
    get v1_facilities_ccp_index_url
    Flipper.enable(:facility_locator_ppms_skip_additional_round_trips, true)
  end

  let(:sha256) { 'bd2b84cc5c0aa3676090eacde32e99c7d668388e5fc5440e3c582aef419fc398' }

  let(:params) do
    {
      latitude: 40.415217,
      longitude: -74.057114,
      radius: 200,
      type: 'provider',
      specialties: ['213E00000X']
    }
  end

  describe '#index' do
    let(:provider_urgent_care) do
      {
        'id' => '1a2ec66b370936eccc980db2fcf4b094fc61a5329aea49744d538f6a9bab2569',
        'type' => 'provider',
        'attributes' =>
        { 'accNewPatients' => 'false',
          'address' => { 'street' => '2 BAYSHORE PLZ', 'city' => 'ATLANTIC HIGHLANDS', 'state' => 'NJ',
                         'zip' => '07716' },
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
          'uniqueId' => '1225028293' }
      }
    end

    context 'Missing Provider', vcr: vcr_options.merge(cassette_name: 'facilities/ppms/ppms_missing_provider') do
      it 'gracefully handles ppms provider lookup failures' do
        get '/v1/facilities/ccp', params: params

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
      end
    end

    context 'Empty Results', vcr: vcr_options.merge(
      cassette_name: 'facilities/ppms/ppms_empty_search',
      match_requests_on: [:method]
    ) do
      it 'responds to GET #index with success even if no providers are found' do
        get '/v1/facilities/ccp', params: params

        expect(response).to be_successful
      end
    end

    context 'type=provider' do
      context 'Missing specialties param' do
        let(:params) do
          {
            latitude: 40.415217,
            longitude: -74.057114,
            radius: 200,
            type: 'provider'
          }
        end

        it 'requires a specialty code' do
          get '/v1/facilities/ccp', params: params

          bod = JSON.parse(response.body)

          expect(bod).to include(
            'errors' => [{
              'title' => 'Missing parameter',
              'detail' => 'The required parameter "specialties", is missing',
              'code' => '108',
              'status' => '400'
            }]
          )

          expect(response).not_to be_successful
        end
      end

      context 'specialties=261QU0200X' do
        let(:params) do
          {
            latitude: 40.415217,
            longitude: -74.057114,
            radius: 200,
            type: 'provider',
            specialties: ['261QU0200X']
          }
        end

        it 'returns a results from the pos_locator' do
          get '/v1/facilities/ccp', params: params

          bod = JSON.parse(response.body)

          expect(bod['data']).to include(provider_urgent_care)

          expect(response).to be_successful
        end
      end

      [
        [1, 5, 6],
        [2, 5, 11],
        [3, 1, 4]
      ].each do |(page, per_page, total_items)|
        it "paginates ppms responses (page: #{page}, per_page: #{per_page}, total_items: #{total_items})" do
          params_with_pagination = params.merge(
            page: page.to_s,
            per_page: per_page.to_s
          )

          client = Facilities::PPMS::V1::Client.new
          expect(Facilities::PPMS::V1::Client).to receive(:new).and_return(client)
          expect(client).to receive(:provider_locator).and_return(
            Facilities::PPMS::V1::Response.new(
              FactoryBot.build_list(:ppms_provider, total_items).collect(&:attributes),
              params_with_pagination
            ).providers
          )
          allow(client).to receive(:provider_info).and_return(
            FactoryBot.build(:ppms_provider)
          )

          get '/v1/facilities/ccp', params: params_with_pagination
          bod = JSON.parse(response.body)

          prev_page = page == 1 ? nil : page - 1
          expect(bod['meta']).to include(
            'pagination' => {
              'current_page' => page,
              'prev_page' => prev_page,
              'next_page' => page + 1,
              'total_pages' => page + 1
            }
          )
        end
      end

      it 'returns a results from the provider_locator' do
        get '/v1/facilities/ccp', params: params

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
          latitude: 40.415217,
          longitude: -74.057114,
          radius: 200,
          type: 'pharmacy'
        }
      end

      it 'returns results from the pos_locator' do
        get '/v1/facilities/ccp', params: params

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
          latitude: 40.415217,
          longitude: -74.057114,
          radius: 200,
          type: 'urgent_care'
        }
      end

      it 'returns results from the pos_locator' do
        get '/v1/facilities/ccp', params: params

        bod = JSON.parse(response.body)

        expect(bod['data']).to include(provider_urgent_care)

        expect(response).to be_successful
      end
    end
  end

  describe '#show' do
    it 'returns RecordNotFound if ppms has no record' do
      pending('This needs an updated VCR tape with a request for a provider by id that isnt found')
      get '/v1/facilities/ccp/ccp_0000000000'

      bod = JSON.parse(response.body)

      expect(bod['errors'].length).to be > 0
      expect(bod['errors'][0]['title']).to eq('Record not found')
    end

    it 'returns a provider' do
      get '/v1/facilities/ccp/1154383230'

      bod = JSON.parse(response.body)

      expect(bod).to include(
        'data' => {
          'id' => '1154383230',
          'type' => 'provider',
          'attributes' => {
            'accNewPatients' => 'true',
            'address' => {
              'street' => '502 CANDLEWOOD CMNS',
              'city' => 'HOWELL',
              'state' => 'NJ',
              'zip' => '07731-2172'
            },
            'caresitePhone' => nil,
            'email' => nil,
            'fax' => nil,
            'gender' => 'Female',
            'lat' => 40.146886,
            'long' => -74.224247,
            'name' => 'GESUALDI, AMY',
            'phone' => nil,
            'posCodes' => nil,
            'prefContact' => nil,
            'uniqueId' => '1154383230'
          }
        }
      )
    end
  end

  describe '#specialties', vcr: vcr_options.merge(cassette_name: 'facilities/ppms/ppms_specialties') do
    it 'returns a list of available specializations' do
      get '/v1/facilities/ccp/specialties'

      bod = JSON.parse(response.body)

      expect(bod['data'][0..1]).to match(
        [{
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
         }]
      )
    end
  end
end
