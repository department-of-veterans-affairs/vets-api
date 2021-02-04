# frozen_string_literal: true

require 'rails_helper'

vcr_options = {
  cassette_name: 'facilities/ppms/ppms',
  match_requests_on: %i[path query],
  allow_playback_repeats: true
}

RSpec.describe 'Community Care Providers', type: :request, team: :facilities, vcr: vcr_options do
  before do
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
    context 'Missing Provider', vcr: vcr_options.merge(cassette_name: 'facilities/ppms/ppms_missing_provider') do
      it 'gracefully handles ppms provider lookup failures' do
        get '/v1/facilities/ccp', params: params

        bod = JSON.parse(response.body)
        expect(bod['data']).to include(
          {
            'id' => '6d4644e7db7491635849b23e20078f74cfcd2d0aeee6a77aca921f5540d03f33',
            'type' => 'provider',
            'attributes' => {
              'acc_new_patients' => 'true',
              'address' => {
                'street' => '176 RIVERSIDE AVE',
                'city' => 'RED BANK',
                'state' => 'NJ',
                'zip' => '07701-1063'
              },
              'caresite_phone' => '732-219-6625',
              'email' => nil,
              'fax' => nil,
              'gender' => 'Female',
              'lat' => 40.35396,
              'long' => -74.07492,
              'name' => 'GESUALDI, AMY',
              'phone' => nil,
              'pos_codes' => nil,
              'pref_contact' => nil,
              'unique_id' => '1154383230'
            }
          }
        )
      end
    end

    context 'type=provider' do
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

          sha256 = 'b09211e205d103edf949d2897dcbe489fb7bc3f2c73f203022b4d7b96e603d0d'

          expect(bod['data']).to include(
            {
              'id' => sha256,
              'type' => 'provider',
              'attributes' => {
                'acc_new_patients' => 'false',
                'address' => {
                  'street' => '5024 5TH AVE',
                  'city' => 'BROOKLYN',
                  'state' => 'NY',
                  'zip' => '11220-1909'
                },
                'caresite_phone' => '718-571-9251',
                'email' => nil,
                'fax' => nil,
                'gender' => 'NotSpecified',
                'lat' => 40.644795,
                'long' => -74.011055,
                'name' => 'CITY MD URGENT CARE',
                'phone' => nil,
                'pos_codes' => '20',
                'pref_contact' => nil,
                'unique_id' => '1487993564'
              }
            }
          )
          expect(response).to be_successful
        end
      end

      it "sends a 'facilities.ppms.request.faraday' notification to any subscribers listening" do
        allow(StatsD).to receive(:measure)

        expect(StatsD).to receive(:measure).with(
          'facilities.ppms.provider_locator',
          kind_of(Numeric),
          hash_including(
            tags: [
              'facilities.ppms',
              'facilities.ppms.radius:200',
              'facilities.ppms.results:11'
            ]
          )
        )

        expect do
          get '/v1/facilities/ccp', params: params
        end.to instrument('facilities.ppms.request.faraday')
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
              'acc_new_patients' => 'true',
              'address' => {
                'street' => '176 RIVERSIDE AVE',
                'city' => 'RED BANK',
                'state' => 'NJ',
                'zip' => '07701-1063'
              },
              'caresite_phone' => '732-219-6625',
              'email' => nil,
              'fax' => nil,
              'gender' => 'Female',
              'lat' => 40.35396,
              'long' => -74.07492,
              'name' => 'GESUALDI, AMY',
              'phone' => nil,
              'pos_codes' => nil,
              'pref_contact' => nil,
              'unique_id' => '1154383230'
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
              'acc_new_patients' => 'false',
              'address' => {
                'street' => '2 BAYSHORE PLZ',
                'city' => 'ATLANTIC HIGHLANDS',
                'state' => 'NJ',
                'zip' => '07716'
              },
              'caresite_phone' => '732-291-2900',
              'email' => nil,
              'fax' => nil,
              'gender' => 'NotSpecified',
              'lat' => 40.409114,
              'long' => -74.041849,
              'name' => 'BAYSHORE PHARMACY',
              'phone' => nil,
              'pos_codes' => nil,
              'pref_contact' => nil,
              'unique_id' => '1225028293'
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

        sha256 = 'b09211e205d103edf949d2897dcbe489fb7bc3f2c73f203022b4d7b96e603d0d'

        expect(bod['data']).to include(
          {
            'id' => sha256,
            'type' => 'provider',
            'attributes' => {
              'acc_new_patients' => 'false',
              'address' => {
                'street' => '5024 5TH AVE',
                'city' => 'BROOKLYN',
                'state' => 'NY',
                'zip' => '11220-1909'
              },
              'caresite_phone' => '718-571-9251',
              'email' => nil,
              'fax' => nil,
              'gender' => 'NotSpecified',
              'lat' => 40.644795,
              'long' => -74.011055,
              'name' => 'CITY MD URGENT CARE',
              'phone' => nil,
              'pos_codes' => '20',
              'pref_contact' => nil,
              'unique_id' => '1487993564'
            }
          }
        )

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

    it 'returns a provider with services' do
      get '/v1/facilities/ccp/1225028293'

      bod = JSON.parse(response.body)

      expect(bod).to include(
        'data' => {
          'id' => '1225028293',
          'type' => 'provider',
          'attributes' => {
            'acc_new_patients' => nil,
            'address' => {
              'street' => '2 BAYSHORE PLZ',
              'city' => 'ATLANTIC HIGHLANDS',
              'state' => 'NJ',
              'zip' => '07716'
            },
            'caresite_phone' => nil,
            'email' => 'MANAGER.BAYSHOREPHARMACY@COMCAST.NET',
            'fax' => nil,
            'gender' => nil,
            'lat' => 40.409114,
            'long' => -74.041849,
            'name' => 'BAYSHORE PHARMACY',
            'phone' => nil,
            'pos_codes' => nil,
            'pref_contact' => nil,
            'unique_id' => '1225028293'
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
            'specialty_code' => '101Y00000X',
            'specialty_description' => 'A provider who is trained and educated in the performance of behavior ' \
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
             'specialty_code' => '101YA0400X',
             'specialty_description' => 'Definition to come...'
           }
         }]
      )
    end
  end
end
