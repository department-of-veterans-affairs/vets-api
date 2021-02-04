# frozen_string_literal: true

require 'rails_helper'

vcr_options = {
  cassette_name: 'facilities/va/ppms_and_lighthouse',
  match_requests_on: %i[path query],
  allow_playback_repeats: true
}

RSpec.describe 'VA and Community Care Mashup', type: :request, team: :facilities, vcr: vcr_options do
  context 'Facilities::PPMS::V1::Client' do
    let(:params) do
      {
        bbox: ['-75.91', '38.55', '-72.19', '42.27'],
        latitude: 40.415217,
        longitude: -74.057114,
        radius: 200,
        type: 'provider'
      }
    end

    describe '#va_ccp/urgent_care' do
      let(:path) { '/v1/facilities/va_ccp/urgent_care' }

      it "sends a 'facilities.ppms.request.faraday' notification to any subscribers listening" do
        allow(StatsD).to receive(:measure)

        expect(StatsD).to receive(:measure).with(
          'facilities.ppms.place_of_service_locator',
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
          get path, params: params
        end.to instrument('facilities.ppms.request.faraday')
      end

      it "sends a 'lighthouse.facilities.request.faraday' notification to any subscribers listening" do
        allow(StatsD).to receive(:measure)

        expect(StatsD).to receive(:measure).with(
          'facilities.lighthouse',
          kind_of(Numeric),
          hash_including(tags: ['facilities.lighthouse'])
        )

        expect do
          get path, params: params
        end.to instrument('lighthouse.facilities.request.faraday')
      end

      it 'returns results from the pos_locator' do
        allow(SecureRandom).to receive(:uuid).and_return('927d31eb-11fd-43c2-ac29-11c1a4128819')

        get path, params: params

        bod = JSON.parse(response.body)

        expect(bod).to match(
          {
            'data' => [
              {
                'id' => '927d31eb-11fd-43c2-ac29-11c1a4128819',
                'type' => 'provider_facility',
                'relationships' => {
                  'providers' => {
                    'data' => [
                      {
                        'id' => 'b09211e205d103edf949d2897dcbe489fb7bc3f2c73f203022b4d7b96e603d0d',
                        'type' => 'provider'
                      },
                      {
                        'id' => '4fd8291ae0bb51e568eb29d215ed5a784f9171b9f98f9963a706a5fc387a24c5',
                        'type' => 'provider'
                      },
                      {
                        'id' => 'a0cfafe8986a6893bfc651244ce6e9fee21dfd3e7c4b82c33062d31281b8989c',
                        'type' => 'provider'
                      },
                      {
                        'id' => '30f247acf7bd6635760a6398043bf0235030e8299aad5390a210f24a3b4684c4',
                        'type' => 'provider'
                      },
                      {
                        'id' => '73f57df2aeda3424246aa1526d91a4eb2e27a6828bb646898a77e87b88b2bab9',
                        'type' => 'provider'
                      },
                      {
                        'id' => 'dfa50f5b6bf7a5ffc36f11f636ef8d51ee1303c102c4fd9c6925ca1c2c433fa7',
                        'type' => 'provider'
                      },
                      {
                        'id' => 'a9e664cb35c5705a371962fca74ea7c2f6b277aa75446673b8795b3afe7f29a1',
                        'type' => 'provider'
                      },
                      {
                        'id' => 'a01a12227953e3b4e538e1ad1eea8a49c8f789ca587e849c13894529553e49b5',
                        'type' => 'provider'
                      },
                      {
                        'id' => 'f6c97daea4f94f7e5c3ed73840ec3f61832da018c2d5e43a884c297dd94019f1',
                        'type' => 'provider'
                      },
                      {
                        'id' => '9a90ec56691c18bfe3a05fa99e44a3a8299700a07b02c1da65aefdaea1d9987c',
                        'type' => 'provider'
                      }
                    ]
                  },
                  'facilities' => {
                    'data' => [
                      {
                        'id' => 'vha_561',
                        'type' => 'facility'
                      }
                    ]
                  }
                }
              }
            ],
            'included' => [
              {
                'id' => 'vha_561',
                'type' => 'facility',
                'attributes' => {
                  'access' => {
                    'health' => [
                      {
                        'service' => 'Audiology',
                        'new' => 39.456,
                        'established' => 32.118421
                      },
                      {
                        'service' => 'Cardiology',
                        'new' => 27.711538,
                        'established' => 20.4
                      },
                      {
                        'service' => 'Dermatology',
                        'new' => 19.785714,
                        'established' => 13.75
                      },
                      {
                        'service' => 'Gastroenterology',
                        'new' => 22.470588,
                        'established' => 16.355555
                      },
                      {
                        'service' => 'Gynecology',
                        'new' => 22.962962,
                        'established' => 5.612903
                      },
                      {
                        'service' => 'MentalHealthCare',
                        'new' => 3.964285,
                        'established' => 1.37902
                      },
                      {
                        'service' => 'Ophthalmology',
                        'new' => 8.25,
                        'established' => 18.841726
                      },
                      {
                        'service' => 'Optometry',
                        'new' => 33.75,
                        'established' => 21.683168
                      },
                      {
                        'service' => 'Orthopedics',
                        'new' => 11.133333,
                        'established' => 1.142857
                      },
                      {
                        'service' => 'PrimaryCare',
                        'new' => 19.391304,
                        'established' => 18.299295
                      },
                      {
                        'service' => 'SpecialtyCare',
                        'new' => 22.659012,
                        'established' => 16.878493
                      },
                      {
                        'service' => 'Urology',
                        'new' => 26.1875,
                        'established' => 2.166666
                      }
                    ],
                    'effective_date' => '2020-11-30'
                  },
                  'active_status' => 'A',
                  'address' => {
                    'mailing' => {
                    },
                    'physical' => {
                      'zip' => '07018-1023',
                      'city' => 'East Orange',
                      'state' => 'NJ',
                      'address_1' => '385 Tremont Avenue',
                      'address_2' => nil,
                      'address_3' => nil
                    }
                  },
                  'classification' => 'VA Medical Center (VAMC)',
                  'facility_type' => 'va_health_facility',
                  'feedback' => {
                    'health' => {
                      'primary_care_urgent' => 0.7400000095367432,
                      'primary_care_routine' => 0.7699999809265137,
                      'specialty_care_urgent' => 0.800000011920929,
                      'specialty_care_routine' => 0.8999999761581421
                    },
                    'effective_date' => '2020-04-16'
                  },
                  'hours' => {
                    'friday' => '24/7',
                    'monday' => '24/7',
                    'sunday' => '24/7',
                    'tuesday' => '24/7',
                    'saturday' => '24/7',
                    'thursday' => '24/7',
                    'wednesday' => '24/7'
                  },
                  'id' => 'vha_561',
                  'lat' => 40.75380161,
                  'long' => -74.23432989,
                  'mobile' => false,
                  'name' => 'East Orange VA Medical Center',
                  'operating_status' => {
                    'code' => 'NORMAL'
                  },
                  'operational_hours_special_instructions' => nil,
                  'phone' => {
                    'fax' => '973-676-4226',
                    'main' => '973-676-1000',
                    'pharmacy' => '800-480-5590',
                    'after_hours' => '973-676-1000',
                    'patient_advocate' => '973-676-1000 x3399',
                    'mental_health_clinic' => '973-676-1000 x 1421',
                    'enrollment_coordinator' => '973-676-1000 x3044'
                  },
                  'services' => {
                    'other' => [],
                    'health' => %w[
                      Audiology
                      Cardiology
                      DentalServices
                      Dermatology
                      EmergencyCare
                      Gastroenterology
                      Gynecology
                      MentalHealthCare
                      Nutrition
                      Ophthalmology
                      Optometry
                      Orthopedics
                      Podiatry
                      PrimaryCare
                      SpecialtyCare
                      UrgentCare
                      Urology
                    ],
                    'last_updated' => '2020-11-30'
                  },
                  'unique_id' => '561',
                  'visn' => '2',
                  'website' => 'https://www.newjersey.va.gov/locations/directions.asp'
                }
              },
              {
                'id' => 'b09211e205d103edf949d2897dcbe489fb7bc3f2c73f203022b4d7b96e603d0d',
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
              },
              {
                'id' => '4fd8291ae0bb51e568eb29d215ed5a784f9171b9f98f9963a706a5fc387a24c5',
                'type' => 'provider',
                'attributes' => {
                  'acc_new_patients' => 'false',
                  'address' => {
                    'street' => '2175 86TH ST',
                    'city' => 'BROOKLYN',
                    'state' => 'NY',
                    'zip' => '11214-3205'
                  },
                  'caresite_phone' => '646-828-6401',
                  'email' => nil,
                  'fax' => nil,
                  'gender' => 'NotSpecified',
                  'lat' => 40.602322,
                  'long' => -73.993869,
                  'name' => 'CITY MD URGENT CARE',
                  'phone' => nil,
                  'pos_codes' => '20',
                  'pref_contact' => nil,
                  'unique_id' => '1487993564'
                }
              },
              {
                'id' => 'a0cfafe8986a6893bfc651244ce6e9fee21dfd3e7c4b82c33062d31281b8989c',
                'type' => 'provider',
                'attributes' => {
                  'acc_new_patients' => 'false',
                  'address' => {
                    'street' => '418 5TH AVE # 420',
                    'city' => 'BROOKLYN',
                    'state' => 'NY',
                    'zip' => '11215-3316'
                  },
                  'caresite_phone' => '718-965-2273',
                  'email' => nil,
                  'fax' => nil,
                  'gender' => 'NotSpecified',
                  'lat' => 40.6698417,
                  'long' => -73.98545,
                  'name' => 'CITY MD URGENT CARE',
                  'phone' => nil,
                  'pos_codes' => '20',
                  'pref_contact' => nil,
                  'unique_id' => '1487993564'
                }
              },
              {
                'id' => '30f247acf7bd6635760a6398043bf0235030e8299aad5390a210f24a3b4684c4',
                'type' => 'provider',
                'attributes' => {
                  'acc_new_patients' => 'false',
                  'address' => {
                    'street' => '712 BRIGHTON BEACH AVE',
                    'city' => 'BROOKLYN',
                    'state' => 'NY',
                    'zip' => '11235-6412'
                  },
                  'caresite_phone' => '718-571-9291',
                  'email' => nil,
                  'fax' => nil,
                  'gender' => 'NotSpecified',
                  'lat' => 40.5776963,
                  'long' => -73.960225,
                  'name' => 'CITY MD URGENT CARE',
                  'phone' => nil,
                  'pos_codes' => '20',
                  'pref_contact' => nil,
                  'unique_id' => '1487993564'
                }
              },
              {
                'id' => '73f57df2aeda3424246aa1526d91a4eb2e27a6828bb646898a77e87b88b2bab9',
                'type' => 'provider',
                'attributes' => {
                  'acc_new_patients' => 'false',
                  'address' => {
                    'street' => '1305 KINGS HWY',
                    'city' => 'BROOKLYN',
                    'state' => 'NY',
                    'zip' => '11229-1903'
                  },
                  'caresite_phone' => '718-280-5172',
                  'email' => nil,
                  'fax' => nil,
                  'gender' => 'NotSpecified',
                  'lat' => 40.608378,
                  'long' => -73.959851,
                  'name' => 'CITY MD URGENT CARE',
                  'phone' => nil,
                  'pos_codes' => '20',
                  'pref_contact' => nil,
                  'unique_id' => '1487993564'
                }
              },
              {
                'id' => 'dfa50f5b6bf7a5ffc36f11f636ef8d51ee1303c102c4fd9c6925ca1c2c433fa7',
                'type' => 'provider',
                'attributes' => {
                  'acc_new_patients' => 'false',
                  'address' => {
                    'street' => '874 FLATBUSH AVE',
                    'city' => 'BROOKLYN',
                    'state' => 'NY',
                    'zip' => '11226-3102'
                  },
                  'caresite_phone' => '718-571-9372',
                  'email' => nil,
                  'fax' => nil,
                  'gender' => 'NotSpecified',
                  'lat' => 40.650747,
                  'long' => -73.959134,
                  'name' => 'CITY MD URGENT CARE',
                  'phone' => nil,
                  'pos_codes' => '20',
                  'pref_contact' => nil,
                  'unique_id' => '1487993564'
                }
              },
              {
                'id' => 'a9e664cb35c5705a371962fca74ea7c2f6b277aa75446673b8795b3afe7f29a1',
                'type' => 'provider',
                'attributes' => {
                  'acc_new_patients' => 'false',
                  'address' => {
                    'street' => '288 FLATBUSH AVE',
                    'city' => 'BROOKLYN',
                    'state' => 'NY',
                    'zip' => '11217-2812'
                  },
                  'caresite_phone' => '718-656-1290',
                  'email' => nil,
                  'fax' => nil,
                  'gender' => 'NotSpecified',
                  'lat' => 40.678175,
                  'long' => -73.97373,
                  'name' => 'CITY MD URGENT CARE',
                  'phone' => nil,
                  'pos_codes' => '20',
                  'pref_contact' => nil,
                  'unique_id' => '1487993564'
                }
              },
              {
                'id' => 'a01a12227953e3b4e538e1ad1eea8a49c8f789ca587e849c13894529553e49b5',
                'type' => 'provider',
                'attributes' => {
                  'acc_new_patients' => 'false',
                  'address' => {
                    'street' => '2125 NOSTRAND AVE',
                    'city' => 'BROOKLYN',
                    'state' => 'NY',
                    'zip' => '11210-3001'
                  },
                  'caresite_phone' => '718-489-3557',
                  'email' => nil,
                  'fax' => nil,
                  'gender' => 'NotSpecified',
                  'lat' => 40.633455,
                  'long' => -73.947402,
                  'name' => 'CITY MD URGENT CARE',
                  'phone' => nil,
                  'pos_codes' => '20',
                  'pref_contact' => nil,
                  'unique_id' => '1487993564'
                }
              },
              {
                'id' => 'f6c97daea4f94f7e5c3ed73840ec3f61832da018c2d5e43a884c297dd94019f1',
                'type' => 'provider',
                'attributes' => {
                  'acc_new_patients' => 'true',
                  'address' => {
                    'street' => '256 UTICA AVE',
                    'city' => 'BROOKLYN',
                    'state' => 'NY',
                    'zip' => '11213-4029'
                  },
                  'caresite_phone' => '718-240-2644',
                  'email' => nil,
                  'fax' => nil,
                  'gender' => 'NotSpecified',
                  'lat' => 40.669966,
                  'long' => -73.931422,
                  'name' => 'CITY MD URGENT CARE',
                  'phone' => nil,
                  'pos_codes' => '20',
                  'pref_contact' => nil,
                  'unique_id' => '1326229022'
                }
              },
              {
                'id' => '9a90ec56691c18bfe3a05fa99e44a3a8299700a07b02c1da65aefdaea1d9987c',
                'type' => 'provider',
                'attributes' => {
                  'acc_new_patients' => 'false',
                  'address' => {
                    'street' => '256 UTICA AVE',
                    'city' => 'BROOKLYN',
                    'state' => 'NY',
                    'zip' => '11213-4029'
                  },
                  'caresite_phone' => '718-571-9355',
                  'email' => nil,
                  'fax' => nil,
                  'gender' => 'NotSpecified',
                  'lat' => 40.669966,
                  'long' => -73.931422,
                  'name' => 'CITY MD URGENT CARE',
                  'phone' => nil,
                  'pos_codes' => '20',
                  'pref_contact' => nil,
                  'unique_id' => '1487993564'
                }
              }
            ]
          }
        )
      end
    end
  end
end
