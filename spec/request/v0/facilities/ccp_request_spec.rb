# frozen_string_literal: true

require 'rails_helper'
require 'facilities/ppms/v0/client'

vcr_options = {
  cassette_name: 'facilities/ppms/ppms',
  match_requests_on: %i[path query],
  allow_playback_repeats: true
}

RSpec.describe 'Community Care Providers', type: :request, team: :facilities, vcr: vcr_options do
  before do
    Flipper.enable(:facility_locator_ppms_location_query, false)
  end

  describe '#index' do
    context 'type=cc_provider' do
      let(:params) do
        {
          address: '58 Leonard Ave, Leonardo, NJ 07737',
          bbox: ['-75.91', '38.55', '-72.19', '42.27'],
          type: 'cc_provider',
          services: ['213E00000X']
        }
      end

      context 'services=261QU0200X' do
        let(:params) do
          {
            address: '58 Leonard Ave, Leonardo, NJ 07737',
            bbox: ['-75.91', '38.55', '-72.19', '42.27'],
            type: 'cc_provider',
            services: ['261QU0200X']
          }
        end

        context 'without :facility_locator_ppms_legacy_urgent_care_to_pos_locator' do
          it 'returns a results from the provider_locator' do
            Flipper.enable(:facility_locator_ppms_legacy_urgent_care_to_pos_locator, false)

            get '/v0/facilities/ccp', params: params

            bod = JSON.parse(response.body)

            expect(bod['data']).to include(
              {
                'id' => 'ccp_1427432244',
                'type' => 'cc_provider',
                'attributes' => {
                  'acc_new_patients' => 'true',
                  'address' => {
                    'street' => '363 State Highway 36',
                    'city' => 'Port Monmouth',
                    'state' => 'NJ',
                    'zip' => '07758'
                  },
                  'caresite_phone' => '7324710400',
                  'email' => nil,
                  'fax' => nil,
                  'gender' => 'NotSpecified',
                  'lat' => 40.428809,
                  'long' => -74.10675,
                  'name' => 'Integrated Medicine Alliance PA',
                  'phone' => nil,
                  'pos_codes' => nil,
                  'pref_contact' => nil,
                  'specialty' => [
                    {
                      'name' => 'Clinic/Center - Urgent Care',
                      'desc' => 'Definition to come...'
                    }
                  ],
                  'unique_id' => '1427432244'
                }
              }
            )
          end
        end

        context 'with :facility_locator_ppms_legacy_urgent_care_to_pos_locator' do
          it 'returns a results from the pos_locator' do
            Flipper.enable(:facility_locator_ppms_legacy_urgent_care_to_pos_locator, true)

            get '/v0/facilities/ccp', params: params

            bod = JSON.parse(response.body)

            expect(bod['data']).to include(
              {
                'id' => 'ccp_263e81aab50e1c4ea77e84ff7130473f074036f0f01e86abe5ad4a1864c77cb9',
                'type' => 'cc_provider',
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
                  'specialty' => [],
                  'unique_id' => '1487993564'
                }
              }
            )
            expect(response).to be_successful
          end
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

        expect(StatsD).to receive(:measure).with(
          'facilities.ppms.providers',
          kind_of(Numeric),
          hash_including(
            tags: ['facilities.ppms']
          )
        ).exactly(10).times

        expect do
          get '/v0/facilities/ccp', params: params
        end.to instrument('facilities.ppms.request.faraday')
      end

      [
        [1, 5],
        [2, 5],
        [3, 1]
      ].each do |(page, per_page)|
        it 'paginates ppms responses' do
          mock_client = double('Facilities::PPMS::V0::Client')
          params_with_pagination = params.merge(
            page: page.to_s,
            per_page: per_page.to_s
          )
          expect(Facilities::PPMS::V0::Client).to receive(:new).and_return(mock_client)
          expect(mock_client).to receive(:provider_locator).with(
            ActionController::Parameters.new(params_with_pagination).permit!
          ).and_return(
            FactoryBot.build_list(:provider, page * per_page)
          )
          allow(mock_client).to receive(:provider_info).and_return(
            FactoryBot.build(:provider)
          )

          get '/v0/facilities/ccp', params: params_with_pagination
          bod = JSON.parse(response.body)
          expect(bod['meta']).to include(
            'pagination' => {
              'current_page' => page,
              'per_page' => per_page,
              'total_pages' => page + 1,
              'total_entries' => (page + 1) * per_page
            }
          )
        end
      end

      it 'returns a results from the provider_locator' do
        get '/v0/facilities/ccp', params: params

        bod = JSON.parse(response.body)

        expect(bod['data']).to include(
          {
            'id' => 'ccp_1154383230',
            'type' => 'cc_provider',
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
              'specialty' => [
                {
                  'name' => 'Podiatrist',
                  'desc' => 'A podiatrist is a person qualified by a Doctor of Podiatric Medicine (D.P.M.) degree, ' \
                            'licensed by the state, and practicing within the scope of that license. Podiatrists ' \
                            'diagnose and treat foot diseases and deformities. They perform medical, surgical and ' \
                            'other operative procedures, prescribe corrective devices and prescribe and administer ' \
                            'drugs and physical therapy.'
                }
              ], 'unique_id' => '1154383230'
            }
          }
        )
        expect(response).to be_successful
      end
    end

    [true, false].each do |t|
      context "#{t ? 'with' : 'without'} :facility_locator_ppms_legacy_urgent_care_to_pos_locator" do
        before do
          Flipper.enable(:facility_locator_ppms_legacy_urgent_care_to_pos_locator, t)
        end

        context 'type=cc_pharmacy' do
          let(:params) do
            {
              address: '58 Leonard Ave, Leonardo, NJ 07737',
              bbox: ['-75.91', '38.55', '-72.19', '42.27'],
              type: 'cc_pharmacy'
            }
          end

          it 'returns results from the pos_locator' do
            get '/v0/facilities/ccp', params: params

            bod = JSON.parse(response.body)

            expect(bod['data']).to include(
              {
                'id' => 'ccp_1225028293',
                'type' => 'cc_provider',
                'attributes' => {
                  'acc_new_patients' => 'false',
                  'address' => {
                    'street' => '2 BAYSHORE PLZ',
                    'city' => 'ATLANTIC HIGHLANDS',
                    'state' => 'NJ',
                    'zip' => '07716'
                  },
                  'caresite_phone' => '732-291-2900',
                  'email' => 'MANAGER.BAYSHOREPHARMACY@COMCAST.NET',
                  'fax' => nil,
                  'gender' => 'NotSpecified',
                  'lat' => 40.409114,
                  'long' => -74.041849,
                  'name' => 'BAYSHORE PHARMACY',
                  'phone' => nil,
                  'pos_codes' => nil,
                  'pref_contact' => nil,
                  'specialty' => [
                    {
                      'name' => 'Pharmacy - Community/Retail Pharmacy',
                      'desc' => 'A pharmacy where pharmacists store, prepare, and dispense medicinal preparations ' \
                                'and/or prescriptions for a local patient population in accordance with federal and ' \
                                'state law; counsel patients and caregivers (sometimes independent of the dispensing ' \
                                'process); administer vaccinations; and provide other professional services '\
                                'associated with pharmaceutical care such as health screenings, consultative ' \
                                'services with other health care providers, collaborative practice, disease state ' \
                                'management, and education classes.'
                    }
                  ],
                  'unique_id' => '1225028293'
                }
              }
            )
            expect(bod['meta']).to include(
              'pagination' => {
                'current_page' => 1,
                'per_page' => 10,
                'total_pages' => 2,
                'total_entries' => 20
              }
            )
            expect(response).to be_successful
          end
        end

        context 'type=cc_urgent_care' do
          let(:params) do
            {
              address: '58 Leonard Ave, Leonardo, NJ 07737',
              bbox: ['-75.91', '38.55', '-72.19', '42.27'],
              type: 'cc_urgent_care'
            }
          end

          it 'returns results from the pos_locator' do
            get '/v0/facilities/ccp', params: params.merge('type' => 'cc_urgent_care')

            bod = JSON.parse(response.body)

            expect(bod['data']).to include(
              {
                'id' => 'ccp_263e81aab50e1c4ea77e84ff7130473f074036f0f01e86abe5ad4a1864c77cb9',
                'type' => 'cc_provider',
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
                  'specialty' => [],
                  'unique_id' => '1487993564'
                }
              }
            )
            expect(bod['meta']).to include(
              'pagination' => {
                'current_page' => 1,
                'per_page' => 10,
                'total_pages' => 2,
                'total_entries' => 20
              }
            )
            expect(response).to be_successful
          end
        end
      end
    end
  end

  describe '#show' do
    it 'indicates an invalid parameter' do
      get '/v0/facilities/ccp/12345'
      expect(response).to have_http_status(:bad_request)

      bod = JSON.parse(response.body)

      expect(bod['errors'].length).to be > 0
      expect(bod['errors'][0]['title']).to eq('Invalid field value')
    end

    it 'returns RecordNotFound if ppms has no record' do
      pending('This needs an updated VCR tape with a request for a provider by id that isnt found')
      get '/v0/facilities/ccp/ccp_0000000000'

      bod = JSON.parse(response.body)

      expect(bod['errors'].length).to be > 0
      expect(bod['errors'][0]['title']).to eq('Record not found')
    end

    it 'returns a provider with services' do
      get '/v0/facilities/ccp/ccp_1225028293'

      bod = JSON.parse(response.body)

      expect(bod).to include(
        'data' => {
          'id' => 'ccp_1225028293',
          'type' => 'cc_provider',
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
            'specialty' => [
              {
                'name' => 'Pharmacy - Community/Retail Pharmacy',
                'desc' => 'A pharmacy where pharmacists store, prepare, and dispense medicinal preparations ' \
                          'and/or prescriptions for a local patient population in accordance with federal and ' \
                          'state law; counsel patients and caregivers (sometimes independent of the dispensing ' \
                          'process); administer vaccinations; and provide other professional services '\
                          'associated with pharmaceutical care such as health screenings, consultative ' \
                          'services with other health care providers, collaborative practice, disease state ' \
                          'management, and education classes.'
              }
            ],
            'unique_id' => '1225028293'
          }
        }
      )
    end
  end

  describe '#services', vcr: vcr_options.merge(cassette_name: 'facilities/ppms/ppms_specialties') do
    it 'returns a provider without services' do
      get '/v0/facilities/services'

      bod = JSON.parse(response.body)

      expect(bod[0..1]).to include(
        {
          'SpecialtyCode' => '101Y00000X',
          'Name' => 'Counselor',
          'Grouping' => 'Behavioral Health & Social Service Providers',
          'Classification' => 'Counselor',
          'Specialization' => nil,
          'SpecialtyDescription' => 'A provider who is trained and educated in the ' \
                            'performance of behavior health services ' \
                            'through interpersonal communications and analysis. ' \
                            'Training and education at the specialty level ' \
                            "usually requires a master's degree and clinical " \
                            'experience and supervision for licensure or ' \
                            'certification.'
        },
        'SpecialtyCode' => '101YA0400X',
        'Name' => 'Counselor - Addiction (Substance Use Disorder)',
        'Grouping' => 'Behavioral Health & Social Service Providers',
        'Classification' => 'Counselor',
        'Specialization' => 'Addiction (Substance Use Disorder)',
        'SpecialtyDescription' => 'Definition to come...'
      )
    end
  end
end
