# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Community Care Providers', type: :request, team: :facilities do
  before do
    Flipper.enable(:facility_locator_ppms_location_query, false)
  end

  around do |example|
    VCR.insert_cassette('facilities/va/ppms', match_requests_on: %i[path query], allow_playback_repeats: true)
    VCR.insert_cassette('facilities/va/ppms_new_query', match_requests_on: %i[path query], allow_playback_repeats: true)
    example.run
    VCR.eject_cassette('facilities/va/ppms_new_query')
    VCR.eject_cassette('facilities/va/ppms')
  end

  describe '#index' do
    context 'type=cc_provider' do
      let(:params) do
        {
          address: 'South Gilbert Road, Chandler, Arizona 85286, United States',
          bbox: ['-112.54', '32.53', '-111.04', '34.03'],
          type: 'cc_provider',
          services: ['213E00000X']
        }
      end

      context 'services=261QU0200X' do
        let(:params) do
          {
            address: 'South Gilbert Road, Chandler, Arizona 85286, United States',
            bbox: ['-112.54', '32.53', '-111.04', '34.03'],
            type: 'cc_provider',
            services: ['261QU0200X']
          }
        end

        context 'without :facility_locator_ppms_legacy_urgent_care_to_pos_locator' do
          it 'returns a results from the provider_locator' do
            Flipper.enable(:facility_locator_ppms_legacy_urgent_care_to_pos_locator, false)

            get '/v0/facilities/ccp', params: params

            bod = JSON.parse(response.body)

            expect(bod).to include(
              'data' => [
                {
                  'id' => 'ccp_1609229764',
                  'type' => 'cc_provider',
                  'attributes' => {
                    'acc_new_patients' => 'true',
                    'address' => {
                      'street' => '3200 S Gilbert Rd',
                      'city' => 'Chandler',
                      'state' => 'AZ',
                      'zip' => '85286'
                    },
                    'caresite_phone' => '4808275700',
                    'email' => nil,
                    'fax' => nil,
                    'gender' => 'NotSpecified',
                    'lat' => 33.259952,
                    'long' => -111.790163,
                    'name' => 'Banner Urgent Care Services LLC',
                    'phone' => nil,
                    'pos_codes' => nil,
                    'pref_contact' => nil,
                    'specialty' => [],
                    'unique_id' => '1609229764'
                  }
                },
                {
                  'id' => 'ccp_1447660816',
                  'type' => 'cc_provider',
                  'attributes' => {
                    'acc_new_patients' => 'true',
                    'address' => {
                      'street' => '2487 S Gilbert Rd Ste A108',
                      'city' => 'Gilbert',
                      'state' => 'AZ',
                      'zip' => '85295'
                    },
                    'caresite_phone' => '4808991341',
                    'email' => 'unknown@unknown.com',
                    'fax' => nil,
                    'gender' => 'NotSpecified',
                    'lat' => 33.30483,
                    'long' => -111.78898,
                    'name' => 'Medpost Urgent Care - Gilbert Fiesta',
                    'phone' => nil,
                    'pos_codes' => nil,
                    'pref_contact' => nil,
                    'specialty' => [],
                    'unique_id' => '1447660816'
                  }
                }
              ]
            )
          end
        end

        context 'with :facility_locator_ppms_legacy_urgent_care_to_pos_locator' do
          it 'returns a results from the pos_locator' do
            Flipper.enable(:facility_locator_ppms_legacy_urgent_care_to_pos_locator, true)

            get '/v0/facilities/ccp', params: params

            bod = JSON.parse(response.body)

            expect(bod).to include(
              'data' => [
                {
                  'id' => 'ccp_485b3868e513c698740c68ebd32b9ea58184c09a01eecc40182a18f6c1dedfb5',
                  'type' => 'cc_provider',
                  'attributes' => {
                    'acc_new_patients' => 'false',
                    'address' => {
                      'street' => '2010 S Dobson Rd',
                      'city' => 'Chandler',
                      'state' => 'AZ',
                      'zip' => '85286'
                    },
                    'caresite_phone' => '8663892727',
                    'email' => nil,
                    'fax' => nil,
                    'gender' => 'NotSpecified',
                    'lat' => 33.275526,
                    'long' => -111.877057,
                    'name' => 'MinuteClinic LLC',
                    'phone' => nil,
                    'pos_codes' => '17',
                    'pref_contact' => nil,
                    'specialty' => [],
                    'unique_id' => '1629245311'
                  }
                },
                {
                  'id' => 'ccp_f4972c93ed6cd25488ee42bce175be9aa676bf2131241fe59d35175e9b7fa278',
                  'type' => 'cc_provider',
                  'attributes' => {
                    'acc_new_patients' => 'false',
                    'address' => {
                      'street' => '1975 S Alma School Rd',
                      'city' => 'Chandler',
                      'state' => 'AZ',
                      'zip' => '85286'
                    },
                    'caresite_phone' => '8559254733',
                    'email' => nil,
                    'fax' => nil,
                    'gender' => 'NotSpecified',
                    'lat' => 33.277213,
                    'long' => -111.857814,
                    'name' => 'Take Care Health Arizona PC',
                    'phone' => nil,
                    'pos_codes' => '17',
                    'pref_contact' => nil,
                    'specialty' => [],
                    'unique_id' => '1992993570'
                  }
                },
                {
                  'id' => 'ccp_596b1f876d318576c8604121c342f85b4e0a57baa1c689ce462f88eeee8ecc97',
                  'type' => 'cc_provider',
                  'attributes' => {
                    'acc_new_patients' => 'false',
                    'address' => {
                      'street' => '600 S Dobson Rd Ste C26',
                      'city' => 'Chandler',
                      'state' => 'AZ',
                      'zip' => '85224'
                    },
                    'caresite_phone' => '4808141560',
                    'email' => nil,
                    'fax' => nil,
                    'gender' => 'NotSpecified',
                    'lat' => 33.2962,
                    'long' => -111.87682,
                    'name' => 'NextCare Urgent Care Dobson',
                    'phone' => nil,
                    'pos_codes' => '20',
                    'pref_contact' => nil,
                    'specialty' => [],
                    'unique_id' => '1043371826'
                  }
                },
                {
                  'id' => 'ccp_1c8a8512f5daf1046e950a6ee2f3af8a350d0f3281f6fd85a60494e11c78fcce',
                  'type' => 'cc_provider',
                  'attributes' => {
                    'acc_new_patients' => 'false',
                    'address' => {
                      'street' => '1155 W Ocotillo Rd Ste 4',
                      'city' => 'Chandler',
                      'state' => 'AZ',
                      'zip' => '85248'
                    },
                    'caresite_phone' => '4803747400',
                    'email' => nil,
                    'fax' => nil,
                    'gender' => 'NotSpecified',
                    'lat' => 33.246766,
                    'long' => -111.866671,
                    'name' => 'NextCare Urgent Care Ocotillo',
                    'phone' => nil,
                    'pos_codes' => '20',
                    'pref_contact' => nil,
                    'specialty' => [],
                    'unique_id' => '1043371826'
                  }
                },
                {
                  'id' => 'ccp_efa5302e3e4a62554562b8a8617d9a67255b8fcb2cb1052e8fe10c859186baff',
                  'type' => 'cc_provider',
                  'attributes' => {
                    'acc_new_patients' => 'false',
                    'address' => {
                      'street' => '5975 W Chandler Blvd',
                      'city' => 'Chandler',
                      'state' => 'AZ',
                      'zip' => '85226'
                    },
                    'caresite_phone' => '8663892727',
                    'email' => nil,
                    'fax' => nil,
                    'gender' => 'NotSpecified',
                    'lat' => 33.30479,
                    'long' => -111.94499,
                    'name' => 'MinuteClinic LLC',
                    'phone' => nil,
                    'pos_codes' => '17',
                    'pref_contact' => nil,
                    'specialty' => [],
                    'unique_id' => '1629245311'
                  }
                },
                {
                  'id' => 'ccp_bb40a8b55b4b30c42d28efa923d8508da71f06a1d9a5eb5d0343ab9a9e998bc8',
                  'type' => 'cc_provider',
                  'attributes' => {
                    'acc_new_patients' => 'false',
                    'address' => {
                      'street' => '2487 S Gilbert Rd Ste A108',
                      'city' => 'Gilbert',
                      'state' => 'AZ',
                      'zip' => '85295'
                    },
                    'caresite_phone' => '4808991341',
                    'email' => nil,
                    'fax' => nil,
                    'gender' => 'NotSpecified',
                    'lat' => 33.305014,
                    'long' => -111.788763,
                    'name' => 'Medpost Urgent Care - Gilbert Fiesta',
                    'phone' => nil,
                    'pos_codes' => '20',
                    'pref_contact' => nil,
                    'specialty' => [],
                    'unique_id' => '1447660816'
                  }
                },
                {
                  'id' => 'ccp_f4e0d537b1279f239622a3c635bc4a1c9b0cfab9465c3552b366d8fa5c1fe83d',
                  'type' => 'cc_provider',
                  'attributes' => {
                    'acc_new_patients' => 'false',
                    'address' => {
                      'street' => '785 S Cooper Rd',
                      'city' => 'Gilbert',
                      'state' => 'AZ',
                      'zip' => '85233'
                    },
                    'caresite_phone' => '8559254733',
                    'email' => nil,
                    'fax' => nil,
                    'gender' => 'NotSpecified',
                    'lat' => 33.336045,
                    'long' => -111.806103,
                    'name' => 'Take Care Health Arizona PC',
                    'phone' => nil,
                    'pos_codes' => '17',
                    'pref_contact' => nil,
                    'specialty' => [],
                    'unique_id' => '1992993570'
                  }
                },
                {
                  'id' => 'ccp_1376b2f242026ed068af34f4e24531f1eab3a5043c402d84bcde4e69804387c4',
                  'type' => 'cc_provider',
                  'attributes' => {
                    'acc_new_patients' => 'false',
                    'address' => {
                      'street' => '2995 E Chandler Heights Rd',
                      'city' => 'Chandler',
                      'state' => 'AZ',
                      'zip' => '85249'
                    },
                    'caresite_phone' => '8663892727',
                    'email' => nil,
                    'fax' => nil,
                    'gender' => 'NotSpecified',
                    'lat' => 33.23309,
                    'long' => -111.79016,
                    'name' => 'MinuteClinic LLC',
                    'phone' => nil,
                    'pos_codes' => '17',
                    'pref_contact' => nil,
                    'specialty' => [],
                    'unique_id' => '1629245311'
                  }
                },
                {
                  'id' => 'ccp_0b766787f4c9c9e5b40d3b45191f9aef28bfad6b568b1104870a41d2d0ab168f',
                  'type' => 'cc_provider',
                  'attributes' => {
                    'acc_new_patients' => 'false',
                    'address' => {
                      'street' => '1710 W Southern Ave',
                      'city' => 'Mesa',
                      'state' => 'AZ',
                      'zip' => '85202'
                    },
                    'caresite_phone' => '8669446046',
                    'email' => nil,
                    'fax' => nil,
                    'gender' => 'NotSpecified',
                    'lat' => 33.3931849665,
                    'long' => -111.8681063774,
                    'name' => 'Concentra Urgent Care',
                    'phone' => nil,
                    'pos_codes' => '20',
                    'pref_contact' => nil,
                    'specialty' => [],
                    'unique_id' => '1871782490'
                  }
                },
                {
                  'id' => 'ccp_14162e717eb34eb738c02bfc294c66eb99fc98fd7e285aa6a8cc627128eb55d5',
                  'type' => 'cc_provider',
                  'attributes' => {
                    'acc_new_patients' => 'false',
                    'address' => {
                      'street' => '6343 S Higley Rd',
                      'city' => 'Gilbert',
                      'state' => 'AZ',
                      'zip' => '85298'
                    },
                    'caresite_phone' => '4807482712',
                    'email' => nil,
                    'fax' => nil,
                    'gender' => 'NotSpecified',
                    'lat' => 33.23498,
                    'long' => -111.71979,
                    'name' => 'NextCare Urgent Care Higley',
                    'phone' => nil,
                    'pos_codes' => '20',
                    'pref_contact' => nil,
                    'specialty' => [],
                    'unique_id' => '1043371826'
                  }
                }
              ]
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
            tags: ['facilities.ppms']
          )
        )

        expect(StatsD).to receive(:measure).with(
          'facilities.ppms.providers',
          kind_of(Numeric),
          hash_including(
            tags: ['facilities.ppms']
          )
        ).exactly(5).times

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
          mock_client = double('Facilities::PPMS::Client')
          params_with_pagination = params.merge(
            page: page.to_s,
            per_page: per_page.to_s
          )
          expect(Facilities::PPMS::Client).to receive(:new).and_return(mock_client)
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

        expect(bod).to include(
          'data' => [
            {
              'id' => 'ccp_1407842941',
              'type' => 'cc_provider',
              'attributes' => {
                'acc_new_patients' => 'true',
                'address' => {
                  'street' => '3195 S Price Rd Ste 148',
                  'city' => 'Chandler',
                  'state' => 'AZ',
                  'zip' => '85248'
                },
                'caresite_phone' => '4807057300',
                'email' => 'evfa1@hotmail.com',
                'fax' => '4809241553',
                'gender' => 'Male',
                'lat' => 33.258135,
                'long' => -111.887927,
                'name' => 'Freed, Lewis',
                'phone' => '4809241552',
                'pos_codes' => nil,
                'pref_contact' => nil,
                'specialty' => [
                  {
                    'name' => 'Podiatrist',
                    'desc' => 'A podiatrist is a person qualified by a Doctor of Podiatric Medicine (D.P.M.) ' \
                              'degree, licensed by the state, and practicing within the scope of that license. ' \
                              'Podiatrists diagnose and treat foot diseases and deformities. They perform medical, ' \
                              'surgical and other operative procedures, prescribe corrective devices and prescribe ' \
                              'and administer drugs and physical therapy.'
                  }
                ],
                'unique_id' => '1407842941'
              }
            }
          ]
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
              address: 'South Gilbert Road, Chandler, Arizona 85286, United States',
              bbox: ['-112.54', '32.53', '-111.04', '34.03'],
              type: 'cc_pharmacy'
            }
          end

          it 'returns results from the pos_locator' do
            get '/v0/facilities/ccp', params: params

            bod = JSON.parse(response.body)

            expect(bod).to include(
              'data' => [
                {
                  'id' => 'ccp_1407842941',
                  'type' => 'cc_provider',
                  'attributes' => {
                    'acc_new_patients' => 'true',
                    'address' => {
                      'street' => '3195 S Price Rd Ste 148',
                      'city' => 'Chandler',
                      'state' => 'AZ',
                      'zip' => '85248'
                    },
                    'caresite_phone' => '4807057300',
                    'email' => 'evfa1@hotmail.com',
                    'fax' => '4809241553',
                    'gender' => 'Male',
                    'lat' => 33.258135,
                    'long' => -111.887927,
                    'name' => 'Freed, Lewis',
                    'phone' => '4809241552',
                    'pos_codes' => nil,
                    'pref_contact' => nil,
                    'specialty' => [
                      {
                        'name' => 'Podiatrist',
                        'desc' => 'A podiatrist is a person qualified by a Doctor of Podiatric Medicine (D.P.M.) ' \
                                  'degree, licensed by the state, and practicing within the scope of that license. ' \
                                  'Podiatrists diagnose and treat foot diseases and deformities. They perform ' \
                                  'medical, surgical and other operative procedures, prescribe corrective devices ' \
                                  'and prescribe and administer drugs and physical therapy.'
                      }
                    ],
                    'unique_id' => '1407842941'
                  }
                }
              ]
            )
            expect(response).to be_successful
          end
        end

        context 'type=cc_urgent_care' do
          let(:params) do
            {
              address: 'South Gilbert Road, Chandler, Arizona 85286, United States',
              bbox: ['-112.54', '32.53', '-111.04', '34.03'],
              type: 'cc_urgent_care'
            }
          end

          it 'returns results from the pos_locator' do
            get '/v0/facilities/ccp', params: params.merge('type' => 'cc_urgent_care')

            bod = JSON.parse(response.body)

            expect(bod).to include(
              'data' => [
                {
                  'id' => 'ccp_485b3868e513c698740c68ebd32b9ea58184c09a01eecc40182a18f6c1dedfb5',
                  'type' => 'cc_provider',
                  'attributes' => {
                    'acc_new_patients' => 'false',
                    'address' => {
                      'street' => '2010 S Dobson Rd',
                      'city' => 'Chandler',
                      'state' => 'AZ',
                      'zip' => '85286'
                    },
                    'caresite_phone' => '8663892727',
                    'email' => nil,
                    'fax' => nil,
                    'gender' => 'NotSpecified',
                    'lat' => 33.275526,
                    'long' => -111.877057,
                    'name' => 'MinuteClinic LLC',
                    'phone' => nil,
                    'pos_codes' => '17',
                    'pref_contact' => nil,
                    'specialty' => [],
                    'unique_id' => '1629245311'
                  }
                },
                {
                  'id' => 'ccp_f4972c93ed6cd25488ee42bce175be9aa676bf2131241fe59d35175e9b7fa278',
                  'type' => 'cc_provider',
                  'attributes' => {
                    'acc_new_patients' => 'false',
                    'address' => {
                      'street' => '1975 S Alma School Rd',
                      'city' => 'Chandler',
                      'state' => 'AZ',
                      'zip' => '85286'
                    },
                    'caresite_phone' => '8559254733',
                    'email' => nil,
                    'fax' => nil,
                    'gender' => 'NotSpecified',
                    'lat' => 33.277213,
                    'long' => -111.857814,
                    'name' => 'Take Care Health Arizona PC',
                    'phone' => nil,
                    'pos_codes' => '17',
                    'pref_contact' => nil,
                    'specialty' => [],
                    'unique_id' => '1992993570'
                  }
                },
                {
                  'id' => 'ccp_596b1f876d318576c8604121c342f85b4e0a57baa1c689ce462f88eeee8ecc97',
                  'type' => 'cc_provider',
                  'attributes' => {
                    'acc_new_patients' => 'false',
                    'address' => {
                      'street' => '600 S Dobson Rd Ste C26',
                      'city' => 'Chandler',
                      'state' => 'AZ',
                      'zip' => '85224'
                    },
                    'caresite_phone' => '4808141560',
                    'email' => nil,
                    'fax' => nil,
                    'gender' => 'NotSpecified',
                    'lat' => 33.2962,
                    'long' => -111.87682,
                    'name' => 'NextCare Urgent Care Dobson',
                    'phone' => nil,
                    'pos_codes' => '20',
                    'pref_contact' => nil,
                    'specialty' => [],
                    'unique_id' => '1043371826'
                  }
                },
                {
                  'id' => 'ccp_1c8a8512f5daf1046e950a6ee2f3af8a350d0f3281f6fd85a60494e11c78fcce',
                  'type' => 'cc_provider',
                  'attributes' => {
                    'acc_new_patients' => 'false',
                    'address' => {
                      'street' => '1155 W Ocotillo Rd Ste 4',
                      'city' => 'Chandler',
                      'state' => 'AZ',
                      'zip' => '85248'
                    },
                    'caresite_phone' => '4803747400',
                    'email' => nil,
                    'fax' => nil,
                    'gender' => 'NotSpecified',
                    'lat' => 33.246766,
                    'long' => -111.866671,
                    'name' => 'NextCare Urgent Care Ocotillo',
                    'phone' => nil,
                    'pos_codes' => '20',
                    'pref_contact' => nil,
                    'specialty' => [],
                    'unique_id' => '1043371826'
                  }
                },
                {
                  'id' => 'ccp_efa5302e3e4a62554562b8a8617d9a67255b8fcb2cb1052e8fe10c859186baff',
                  'type' => 'cc_provider',
                  'attributes' => {
                    'acc_new_patients' => 'false',
                    'address' => {
                      'street' => '5975 W Chandler Blvd',
                      'city' => 'Chandler',
                      'state' => 'AZ',
                      'zip' => '85226'
                    },
                    'caresite_phone' => '8663892727',
                    'email' => nil,
                    'fax' => nil,
                    'gender' => 'NotSpecified',
                    'lat' => 33.30479,
                    'long' => -111.94499,
                    'name' => 'MinuteClinic LLC',
                    'phone' => nil,
                    'pos_codes' => '17',
                    'pref_contact' => nil,
                    'specialty' => [],
                    'unique_id' => '1629245311'
                  }
                },
                {
                  'id' => 'ccp_bb40a8b55b4b30c42d28efa923d8508da71f06a1d9a5eb5d0343ab9a9e998bc8',
                  'type' => 'cc_provider',
                  'attributes' => {
                    'acc_new_patients' => 'false',
                    'address' => {
                      'street' => '2487 S Gilbert Rd Ste A108',
                      'city' => 'Gilbert',
                      'state' => 'AZ',
                      'zip' => '85295'
                    },
                    'caresite_phone' => '4808991341',
                    'email' => nil,
                    'fax' => nil,
                    'gender' => 'NotSpecified',
                    'lat' => 33.305014,
                    'long' => -111.788763,
                    'name' => 'Medpost Urgent Care - Gilbert Fiesta',
                    'phone' => nil,
                    'pos_codes' => '20',
                    'pref_contact' => nil,
                    'specialty' => [],
                    'unique_id' => '1447660816'
                  }
                },
                {
                  'id' => 'ccp_f4e0d537b1279f239622a3c635bc4a1c9b0cfab9465c3552b366d8fa5c1fe83d',
                  'type' => 'cc_provider',
                  'attributes' => {
                    'acc_new_patients' => 'false',
                    'address' => {
                      'street' => '785 S Cooper Rd',
                      'city' => 'Gilbert',
                      'state' => 'AZ',
                      'zip' => '85233'
                    },
                    'caresite_phone' => '8559254733',
                    'email' => nil,
                    'fax' => nil,
                    'gender' => 'NotSpecified',
                    'lat' => 33.336045,
                    'long' => -111.806103,
                    'name' => 'Take Care Health Arizona PC',
                    'phone' => nil,
                    'pos_codes' => '17',
                    'pref_contact' => nil,
                    'specialty' => [],
                    'unique_id' => '1992993570'
                  }
                },
                {
                  'id' => 'ccp_1376b2f242026ed068af34f4e24531f1eab3a5043c402d84bcde4e69804387c4',
                  'type' => 'cc_provider',
                  'attributes' => {
                    'acc_new_patients' => 'false',
                    'address' => {
                      'street' => '2995 E Chandler Heights Rd',
                      'city' => 'Chandler',
                      'state' => 'AZ',
                      'zip' => '85249'
                    },
                    'caresite_phone' => '8663892727',
                    'email' => nil,
                    'fax' => nil,
                    'gender' => 'NotSpecified',
                    'lat' => 33.23309,
                    'long' => -111.79016,
                    'name' => 'MinuteClinic LLC',
                    'phone' => nil,
                    'pos_codes' => '17',
                    'pref_contact' => nil,
                    'specialty' => [],
                    'unique_id' => '1629245311'
                  }
                },
                {
                  'id' => 'ccp_0b766787f4c9c9e5b40d3b45191f9aef28bfad6b568b1104870a41d2d0ab168f',
                  'type' => 'cc_provider',
                  'attributes' => {
                    'acc_new_patients' => 'false',
                    'address' => {
                      'street' => '1710 W Southern Ave',
                      'city' => 'Mesa',
                      'state' => 'AZ',
                      'zip' => '85202'
                    },
                    'caresite_phone' => '8669446046',
                    'email' => nil,
                    'fax' => nil,
                    'gender' => 'NotSpecified',
                    'lat' => 33.3931849665,
                    'long' => -111.8681063774,
                    'name' => 'Concentra Urgent Care',
                    'phone' => nil,
                    'pos_codes' => '20',
                    'pref_contact' => nil,
                    'specialty' => [],
                    'unique_id' => '1871782490'
                  }
                },
                {
                  'id' => 'ccp_14162e717eb34eb738c02bfc294c66eb99fc98fd7e285aa6a8cc627128eb55d5',
                  'type' => 'cc_provider',
                  'attributes' => {
                    'acc_new_patients' => 'false',
                    'address' => {
                      'street' => '6343 S Higley Rd',
                      'city' => 'Gilbert',
                      'state' => 'AZ',
                      'zip' => '85298'
                    },
                    'caresite_phone' => '4807482712',
                    'email' => nil,
                    'fax' => nil,
                    'gender' => 'NotSpecified',
                    'lat' => 33.23498,
                    'long' => -111.71979,
                    'name' => 'NextCare Urgent Care Higley',
                    'phone' => nil,
                    'pos_codes' => '20',
                    'pref_contact' => nil,
                    'specialty' => [],
                    'unique_id' => '1043371826'
                  }
                }
              ],
              'meta' => {
                'pagination' => {
                  'current_page' => 1,
                  'per_page' => 10,
                  'total_pages' => 2,
                  'total_entries' => 20
                }
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
      get '/v0/facilities/ccp/ccp_1407842941'

      bod = JSON.parse(response.body)

      expect(bod).to include(
        'data' => {
          'id' => 'ccp_1407842941',
          'type' => 'cc_provider',
          'attributes' => {
            'acc_new_patients' => 'true',
            'address' => {
              'street' => '6116 E Arbor Ave Ste 118',
              'city' => 'Mesa',
              'state' => 'AZ',
              'zip' => '85206'
            },
            'caresite_phone' => nil,
            'email' => 'evfa1@hotmail.com',
            'fax' => '4809241553',
            'gender' => 'Male',
            'lat' => 33.413705,
            'long' => -111.698513,
            'name' => 'Freed, Lewis',
            'phone' => '4809241552',
            'pos_codes' => nil,
            'pref_contact' => nil,
            'specialty' => [
              {
                'name' => 'Podiatrist',
                'desc' => 'A podiatrist is a person qualified by a Doctor of ' \
                          'Podiatric Medicine (D.P.M.) degree, licensed by the ' \
                          'state, and practicing within the scope of that ' \
                          'license. Podiatrists diagnose and treat foot ' \
                          'diseases and deformities. They perform medical, ' \
                          'surgical and other operative procedures, prescribe ' \
                          'corrective devices and prescribe and administer ' \
                          'drugs and physical therapy.'
              }
            ],
            'unique_id' => '1407842941'
          }
        }
      )
    end
  end

  describe '#services' do
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
