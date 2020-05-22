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
              'id' => 'ccp_1629245311',
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
              'id' => 'ccp_1992993570',
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
              'id' => 'ccp_1043371826',
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
              'id' => 'ccp_1447660816',
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
              'id' => 'ccp_1871782490',
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
