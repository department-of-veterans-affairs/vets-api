# frozen_string_literal: true

require 'rails_helper'

vcr_options = {
  cassette_name: 'facilities/ppms/ppms',
  match_requests_on: %i[path query],
  allow_playback_repeats: true,
  record: :new_episodes
}

RSpec.describe 'Community Care Providers', type: :request, team: :facilities, vcr: vcr_options do
  [0, 1].each do |client_version|
    context "Facilities::PPMS::V#{client_version}::Client" do
      before do
        Flipper.enable(:facility_locator_ppms_use_v1_client, client_version == 1)
      end

      describe '#index' do
        context 'Missing Provider', vcr: vcr_options.merge(cassette_name: 'facilities/ppms/ppms_missing_provider') do
          let(:params) do
            {
              address: 'South Gilbert Road, Chandler, Arizona 85286, United States',
              bbox: ['-112.54', '32.53', '-111.04', '34.03'],
              type: 'provider',
              specialties: ['213E00000X']
            }
          end

          it 'gracefully handles ppms provider lookup failures' do
            get '/v1/facilities/ccp', params: params

            bod = JSON.parse(response.body)
            expect(bod).to include(
              'data' => [
                {
                  'id' => '1407842941',
                  'type' => 'provider',
                  'attributes' => {
                    'acc_new_patients' => 'true',
                    'address' => {
                      'street' => '3195 S Price Rd Ste 148',
                      'city' => 'Chandler',
                      'state' => 'AZ',
                      'zip' => '85248'
                    },
                    'caresite_phone' => '4807057300',
                    'email' => nil,
                    'fax' => nil,
                    'gender' => 'Male',
                    'lat' => 33.258135,
                    'long' => -111.887927,
                    'name' => 'Freed, Lewis',
                    'phone' => nil,
                    'pos_codes' => nil,
                    'pref_contact' => nil,
                    'unique_id' => '1407842941'
                  },
                  'relationships' => {
                    'specialties' => {
                      'data' => []
                    }
                  }
                }
              ],
              'included' => []
            )
          end
        end

        context 'type=provider' do
          let(:params) do
            {
              address: 'South Gilbert Road, Chandler, Arizona 85286, United States',
              bbox: ['-112.54', '32.53', '-111.04', '34.03'],
              type: 'provider',
              specialties: ['213E00000X']
            }
          end

          context 'specialties=261QU0200X' do
            let(:params) do
              {
                address: 'South Gilbert Road, Chandler, Arizona 85286, United States',
                bbox: ['-112.54', '32.53', '-111.04', '34.03'],
                type: 'provider',
                specialties: ['261QU0200X']
              }
            end

            it 'returns a results from the pos_locator' do
              get '/v1/facilities/ccp', params: params

              bod = JSON.parse(response.body)

              sha256 = if Flipper.enabled?(:facility_locator_ppms_use_v1_client)
                         '104ecb200e22dfd96f759bcdd27c6c174ee35c02394bc4d199aaccb51d8486f3'
                       else
                         '398681135712746c43545dad381cacaba234e249f02459246ae709a6200f6c41'
                       end

              expect(bod['data']).to include(
                {
                  'id' => sha256,
                  'type' => 'provider',
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
                    'pos_codes' => '20',
                    'pref_contact' => nil,
                    'unique_id' => '1609229764'
                  },
                  'relationships' => {
                    'specialties' => {
                      'data' => []
                    }
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
                tags: ['facilities.ppms']
              )
            )

            expect(StatsD).to receive(:measure).with(
              'facilities.ppms.providers',
              kind_of(Numeric),
              hash_including(
                tags: ['facilities.ppms']
              )
            ).exactly(7).times

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

              case client_version
              when 0
                mock_client = instance_double('Facilities::PPMS::V0::Client')
                expect(Facilities::PPMS::V0::Client).to receive(:new).and_return(mock_client)
                expect(mock_client).to receive(:provider_locator).with(
                  ActionController::Parameters.new(params_with_pagination).permit!
                ).and_return(
                  FactoryBot.build_list(:provider, total_items)
                )
                allow(mock_client).to receive(:provider_info).and_return(
                  FactoryBot.build(:provider)
                )
              when 1
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
              end

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
                'id' => '1386050060',
                'type' => 'provider',
                'attributes' => {
                  'acc_new_patients' => 'true',
                  'address' => {
                    'street' => '1831 E Queen Creek Rd Ste 119',
                    'city' => 'Chandler',
                    'state' => 'AZ',
                    'zip' => '85286'
                  },
                  'caresite_phone' => '4809172300',
                  'email' => 'Klloyd@facaaz.com',
                  'fax' => nil,
                  'gender' => 'Male',
                  'lat' => 33.262403,
                  'long' => -111.808538,
                  'name' => 'OBryant, Steven',
                  'phone' => nil,
                  'pos_codes' => nil,
                  'pref_contact' => nil,
                  'unique_id' => '1386050060'
                },
                'relationships' => {
                  'specialties' => {
                    'data' => [
                      {
                        'id' => '213E00000X',
                        'type' => 'specialty'
                      }
                    ]
                  }
                }
              }
            )
            expect(bod['included']).to include(
              {
                'id' => '213E00000X',
                'type' => 'specialty',
                'attributes' => {
                  'classification' => 'Podiatrist',
                  'grouping' => 'Podiatric Medicine & Surgery Service Providers',
                  'name' => 'Podiatrist',
                  'specialization' => nil,
                  'specialty_code' => '213E00000X',
                  'specialty_description' => 'A podiatrist is a person qualified by a Doctor of Podiatric Medicine ' \
                                             '(D.P.M.) degree, licensed by the state, and practicing within the ' \
                                             'scope of that license. Podiatrists diagnose and treat foot diseases ' \
                                             'and deformities. They perform medical, surgical and other operative ' \
                                             'procedures, prescribe corrective devices and prescribe and administer ' \
                                             'drugs and physical therapy.'
                }
              }
            )

            expect(response).to be_successful
          end
        end

        context 'type=pharmacy' do
          let(:params) do
            {
              address: 'South Gilbert Road, Chandler, Arizona 85286, United States',
              bbox: ['-112.54', '32.53', '-111.04', '34.03'],
              type: 'pharmacy'
            }
          end

          it 'returns results from the pos_locator' do
            get '/v1/facilities/ccp', params: params

            bod = JSON.parse(response.body)
            expect(bod['data']).to include(
              {
                'id' => '1972660348',
                'type' => 'provider',
                'attributes' =>
                 {
                   'acc_new_patients' => 'false',
                   'address' => {
                     'street' => '2750 E GERMANN RD',
                     'city' => 'CHANDLER',
                     'state' => 'AZ',
                     'zip' => '85249'
                   },
                   'caresite_phone' => '4808122942',
                   'email' => 'ENROLLM@WAL-MART.COM',
                   'fax' => nil,
                   'gender' => 'NotSpecified',
                   'lat' => 33.281291,
                   'long' => -111.793486,
                   'name' => 'WAL-MART',
                   'phone' => nil,
                   'pos_codes' => nil,
                   'pref_contact' => nil,
                   'unique_id' => '1972660348'
                 },
                'relationships' => {
                  'specialties' => {
                    'data' => [
                      {
                        'id' => '3336C0003X',
                        'type' => 'specialty'
                      }
                    ]
                  }
                }
              }
            )

            expect(bod['included'][0]).to match(
              {
                'id' => '3336C0003X',
                'type' => 'specialty',
                'attributes' => {
                  'classification' => 'Pharmacy',
                  'grouping' => 'Suppliers',
                  'name' => 'Pharmacy - Community/Retail Pharmacy',
                  'specialization' => 'Community/Retail Pharmacy',
                  'specialty_code' => '3336C0003X',
                  'specialty_description' => 'A pharmacy where pharmacists store, prepare, and dispense medicinal ' \
                    'preparations and/or prescriptions for a local patient population in accordance with federal and ' \
                    'state law; counsel patients and caregivers (sometimes independent of the dispensing process); ' \
                    'administer vaccinations; and provide other professional services associated with pharmaceutical ' \
                    'care such as health screenings, consultative services with other health care providers, ' \
                    'collaborative practice, disease state management, and education classes.'
                }
              }
            )
            expect(response).to be_successful
          end
        end

        context 'type=urgent_care' do
          let(:params) do
            {
              address: 'South Gilbert Road, Chandler, Arizona 85286, United States',
              bbox: ['-112.54', '32.53', '-111.04', '34.03'],
              type: 'urgent_care',
              per_page: 10
            }
          end

          it 'returns results from the pos_locator' do
            get '/v1/facilities/ccp', params: params

            bod = JSON.parse(response.body)

            sha256 = if Flipper.enabled?(:facility_locator_ppms_use_v1_client)
                       '104ecb200e22dfd96f759bcdd27c6c174ee35c02394bc4d199aaccb51d8486f3'
                     else
                       '398681135712746c43545dad381cacaba234e249f02459246ae709a6200f6c41'
                     end

            expect(bod['data']).to include(
              {
                'id' => sha256,
                'type' => 'provider',
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
                  'pos_codes' => '20',
                  'pref_contact' => nil,
                  'unique_id' => '1609229764'
                },
                'relationships' => {
                  'specialties' => {
                    'data' => []
                  }
                }
              }
            )

            expect(bod['meta']).to include(
              {
                'pagination' => {
                  'current_page' => 1,
                  'prev_page' => nil,
                  'next_page' => 2,
                  'total_pages' => 2
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
          get '/v1/facilities/ccp/1972660348'

          bod = JSON.parse(response.body)

          expect(bod).to include(
            'data' => {
              'id' => '1972660348',
              'type' => 'provider',
              'attributes' => {
                'acc_new_patients' => nil,
                'address' => {
                  'street' => '2750 E GERMANN RD',
                  'city' => 'CHANDLER',
                  'state' => 'AZ',
                  'zip' => '85286'
                },
                'caresite_phone' => nil,
                'email' => 'ENROLLM@WAL-MART.COM',
                'fax' => nil,
                'gender' => nil,
                'lat' => 33.281525,
                'long' => -111.793404,
                'name' => 'WALMART',
                'phone' => nil,
                'pos_codes' => nil,
                'pref_contact' => nil,
                'unique_id' => '1972660348'
              },
              'relationships' => {
                'specialties' => {
                  'data' => [
                    {
                      'id' => '3336C0003X',
                      'type' => 'specialty'
                    }
                  ]
                }
              }
            },
            'included' => [
              {
                'id' => '3336C0003X',
                'type' => 'specialty',
                'attributes' => {
                  'classification' => 'Pharmacy',
                  'grouping' => 'Suppliers',
                  'name' => 'Pharmacy - Community/Retail Pharmacy',
                  'specialization' => 'Community/Retail Pharmacy',
                  'specialty_code' => '3336C0003X',
                  'specialty_description' => 'A pharmacy where pharmacists store, prepare, and dispense medicinal ' \
                    'preparations and/or prescriptions for a local patient population in accordance with federal and ' \
                    'state law; counsel patients and caregivers (sometimes independent of the dispensing process); ' \
                    'administer vaccinations; and provide other professional services associated with pharmaceutical ' \
                    'care such as health screenings, consultative services with other health care providers, ' \
                    'collaborative practice, disease state management, and education classes.'
                }
              }
            ]
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
  end
end
