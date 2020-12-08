# frozen_string_literal: true

require 'rails_helper'

vcr_options = {
  cassette_name: 'facilities/va/ppms_and_lighthouse',
  match_requests_on: %i[path query],
  allow_playback_repeats: true
}

RSpec.describe 'VA and Community Care Mashup', type: :request, team: :facilities, vcr: vcr_options do
  [0, 1].each do |client_version|
    context "Facilities::PPMS::V#{client_version}::Client" do
      before do
        Flipper.enable(:facility_locator_ppms_use_v1_client, client_version == 1)
      end

      let(:params) do
        case client_version
        when 0
          {
            address: '58 Leonard Ave, Leonardo, NJ 07737',
            bbox: ['-75.877', '38.543', '-72.240', '42.236'],
            type: 'provider'
          }
        when 1
          {
            bbox: ['-75.877', '38.543', '-72.240', '42.236'],
            latitude: 40.415217,
            longitude: -74.057114,
            radius: 251,
            type: 'provider'
          }
        end
      end

      describe '#va_ccp/urgent_care' do
        let(:path) { '/v1/facilities/va_ccp/urgent_care' }

        it "sends a 'facilities.ppms.request.faraday' notification to any subscribers listening" do
          allow(StatsD).to receive(:measure)

          expect(StatsD).to receive(:measure).with(
            'facilities.ppms.place_of_service_locator',
            kind_of(Numeric),
            hash_including(tags: ['facilities.ppms'])
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
                        },
                        {
                          'id' => 'vha_620',
                          'type' => 'facility'
                        },
                        {
                          'id' => 'vha_620A4',
                          'type' => 'facility'
                        },
                        {
                          'id' => 'vha_689',
                          'type' => 'facility'
                        },
                        {
                          'id' => 'vha_542',
                          'type' => 'facility'
                        },
                        {
                          'id' => 'vha_689A4',
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
                          'new' => 49.823529,
                          'established' => 22.705882
                        },
                        {
                          'service' => 'Cardiology',
                          'new' => 17.736842,
                          'established' => 14.652173
                        },
                        {
                          'service' => 'Dermatology',
                          'new' => 4.185185,
                          'established' => 2.0
                        },
                        {
                          'service' => 'Gastroenterology',
                          'new' => 3.875,
                          'established' => 13.333333
                        },
                        {
                          'service' => 'Gynecology',
                          'new' => 22.461538,
                          'established' => 11.230769
                        },
                        {
                          'service' => 'MentalHealthCare',
                          'new' => 6.891304,
                          'established' => 0.957575
                        },
                        {
                          'service' => 'Ophthalmology',
                          'new' => 4.090909,
                          'established' => 8.266666
                        },
                        {
                          'service' => 'Optometry',
                          'new' => 0.0,
                          'established' => 60.053763
                        },
                        {
                          'service' => 'Orthopedics',
                          'new' => 5.130434,
                          'established' => 0.445945
                        },
                        {
                          'service' => 'PrimaryCare',
                          'new' => 5.95,
                          'established' => 2.883495
                        },
                        {
                          'service' => 'SpecialtyCare',
                          'new' => 17.447457,
                          'established' => 10.865472
                        },
                        {
                          'service' => 'Urology',
                          'new' => 63.333333,
                          'established' => 0.6
                        }
                      ],
                      'effective_date' => '2020-07-27'
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
                      'last_updated' => '2020-07-27'
                    },
                    'unique_id' => '561',
                    'visn' => '2',
                    'website' => 'https://www.newjersey.va.gov/locations/directions.asp'
                  }
                },
                {
                  'id' => 'vha_620',
                  'type' => 'facility',
                  'attributes' => {
                    'access' => {
                      'health' => [
                        {
                          'service' => 'Cardiology',
                          'new' => 2.0,
                          'established' => 1.5
                        },
                        {
                          'service' => 'MentalHealthCare',
                          'new' => 4.0,
                          'established' => 0.63
                        },
                        {
                          'service' => 'Optometry',
                          'new' => 5.272727,
                          'established' => 1.448717
                        },
                        {
                          'service' => 'PrimaryCare',
                          'new' => 3.09375,
                          'established' => 0.961904
                        },
                        {
                          'service' => 'SpecialtyCare',
                          'new' => 8.652173,
                          'established' => 17.077319
                        }
                      ],
                      'effective_date' => '2020-07-27'
                    },
                    'active_status' => 'A',
                    'address' => {
                      'mailing' => {
                      },
                      'physical' => {
                        'zip' => '10548-1454',
                        'city' => 'Montrose',
                        'state' => 'NY',
                        'address_1' => '2094 Albany Post Road',
                        'address_2' => nil,
                        'address_3' => nil
                      }
                    },
                    'classification' => 'VA Medical Center (VAMC)',
                    'facility_type' => 'va_health_facility',
                    'feedback' => {
                      'health' => {
                        'primary_care_urgent' => 0.949999988079071,
                        'primary_care_routine' => 0.8500000238418579,
                        'specialty_care_urgent' => 0.9200000166893005,
                        'specialty_care_routine' => 0.949999988079071
                      },
                      'effective_date' => '2020-04-16'
                    },
                    'hours' => {
                      'friday' => '800AM-800PM',
                      'monday' => '800AM-800PM',
                      'sunday' => '800AM-600PM',
                      'tuesday' => '800AM-800PM',
                      'saturday' => '800AM-600PM',
                      'thursday' => '800AM-800PM',
                      'wednesday' => '800AM-800PM'
                    },
                    'id' => 'vha_620',
                    'lat' => 41.24466,
                    'long' => -73.926261,
                    'mobile' => false,
                    'name' => 'Franklin Delano Roosevelt Hospital',
                    'operating_status' => {
                      'code' => 'NORMAL'
                    },
                    'phone' => {
                      'fax' => '914-788-4244',
                      'main' => '914-737-4400',
                      'pharmacy' => '888-389-6528',
                      'after_hours' => '914-737-4400',
                      'patient_advocate' => '914-737-4400 x2020',
                      'mental_health_clinic' => '914-737-4400 x 2330',
                      'enrollment_coordinator' => '914-737-4400 x2306'
                    },
                    'services' => {
                      'other' => [],
                      'health' => %w[
                        Cardiology
                        DentalServices
                        MentalHealthCare
                        Nutrition
                        Optometry
                        Podiatry
                        PrimaryCare
                        SpecialtyCare
                        UrgentCare
                      ],
                      'last_updated' => '2020-07-27'
                    },
                    'unique_id' => '620',
                    'visn' => '2',
                    'website' => 'https://www.hudsonvalley.va.gov/locations/directions.asp'
                  }
                },
                {
                  'id' => 'vha_620A4',
                  'type' => 'facility',
                  'attributes' => {
                    'access' => {
                      'health' => [
                        {
                          'service' => 'Audiology',
                          'new' => 5.066666,
                          'established' => 0.35
                        },
                        {
                          'service' => 'Cardiology',
                          'new' => 9.764705,
                          'established' => 3.943925
                        },
                        {
                          'service' => 'Dermatology',
                          'new' => 28.833333,
                          'established' => 11.771929
                        },
                        {
                          'service' => 'Gastroenterology',
                          'new' => 5.6,
                          'established' => 11.34375
                        },
                        {
                          'service' => 'Gynecology',
                          'new' => nil,
                          'established' => 4.666666
                        },
                        {
                          'service' => 'MentalHealthCare',
                          'new' => 4.2,
                          'established' => 0.41
                        },
                        {
                          'service' => 'Optometry',
                          'new' => 2.636363,
                          'established' => 0.252631
                        },
                        {
                          'service' => 'PrimaryCare',
                          'new' => 10.795918,
                          'established' => 1.840206
                        },
                        {
                          'service' => 'SpecialtyCare',
                          'new' => 10.532374,
                          'established' => 4.791898
                        },
                        {
                          'service' => 'Urology',
                          'new' => 13.954545,
                          'established' => 7.5
                        }
                      ],
                      'effective_date' => '2020-07-27'
                    },
                    'active_status' => 'A',
                    'address' => {
                      'mailing' => {
                      },
                      'physical' => {
                        'zip' => '12590-7004',
                        'city' => 'Wappingers Falls',
                        'state' => 'NY',
                        'address_1' => '41 Castle Point Road',
                        'address_2' => nil,
                        'address_3' => nil
                      }
                    },
                    'classification' => 'VA Medical Center (VAMC)',
                    'facility_type' => 'va_health_facility',
                    'feedback' => {
                      'health' => {
                        'primary_care_urgent' => 0.800000011920929,
                        'primary_care_routine' => 0.9100000262260437
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
                    'id' => 'vha_620A4',
                    'lat' => 41.54039811,
                    'long' => -73.96220178,
                    'mobile' => false,
                    'name' => 'Castle Point VA Medical Center',
                    'operating_status' => {
                      'code' => 'NORMAL'
                    },
                    'phone' => {
                      'fax' => '845-838-5193',
                      'main' => '845-831-2000',
                      'pharmacy' => '888-389-6528',
                      'after_hours' => '845-831-2000',
                      'patient_advocate' => '845-831-2000 x5795',
                      'mental_health_clinic' => '845-831-2000 x 5116',
                      'enrollment_coordinator' => '845-831-2000 x5100'
                    },
                    'services' => {
                      'other' => [],
                      'health' => %w[
                        Audiology
                        Cardiology
                        DentalServices
                        Dermatology
                        Gastroenterology
                        Gynecology
                        MentalHealthCare
                        Nutrition
                        Optometry
                        Podiatry
                        PrimaryCare
                        SpecialtyCare
                        UrgentCare
                        Urology
                      ],
                      'last_updated' => '2020-07-27'
                    },
                    'unique_id' => '620A4',
                    'visn' => '2',
                    'website' => 'https://www.hudsonvalley.va.gov/locations/Castle_Point_Campus.asp'
                  }
                },
                {
                  'id' => 'vha_689',
                  'type' => 'facility',
                  'attributes' => {
                    'access' => {
                      'health' => [
                        {
                          'service' => 'Audiology',
                          'new' => 11.121212,
                          'established' => 8.549295
                        },
                        {
                          'service' => 'Cardiology',
                          'new' => 24.466666,
                          'established' => 7.717842
                        },
                        {
                          'service' => 'Dermatology',
                          'new' => 22.533333,
                          'established' => 2.569892
                        },
                        {
                          'service' => 'Gastroenterology',
                          'new' => 18.8,
                          'established' => 8.92
                        },
                        {
                          'service' => 'Gynecology',
                          'new' => 7.142857,
                          'established' => 1.482758
                        },
                        {
                          'service' => 'MentalHealthCare',
                          'new' => 4.352941,
                          'established' => 1.651348
                        },
                        {
                          'service' => 'Ophthalmology',
                          'new' => 14.846153,
                          'established' => 8.893081
                        },
                        {
                          'service' => 'Optometry',
                          'new' => 21.830188,
                          'established' => 5.345104
                        },
                        {
                          'service' => 'Orthopedics',
                          'new' => 16.818181,
                          'established' => 8.085714
                        },
                        {
                          'service' => 'PrimaryCare',
                          'new' => 4.55,
                          'established' => 3.487752
                        },
                        {
                          'service' => 'SpecialtyCare',
                          'new' => 17.755555,
                          'established' => 8.987563
                        },
                        {
                          'service' => 'Urology',
                          'new' => 16.023809,
                          'established' => 12.819819
                        },
                        {
                          'service' => 'WomensHealth',
                          'new' => nil,
                          'established' => 0.784615
                        }
                      ],
                      'effective_date' => '2020-07-27'
                    },
                    'active_status' => 'A',
                    'address' => {
                      'mailing' => {
                      },
                      'physical' => {
                        'zip' => '06516-2770',
                        'city' => 'West Haven',
                        'state' => 'CT',
                        'address_1' => '950 Campbell Avenue',
                        'address_2' => nil,
                        'address_3' => nil
                      }
                    },
                    'classification' => 'VA Medical Center (VAMC)',
                    'facility_type' => 'va_health_facility',
                    'feedback' => {
                      'health' => {
                        'primary_care_urgent' => 0.9200000166893005,
                        'primary_care_routine' => 0.9300000071525574,
                        'specialty_care_urgent' => 0.8399999737739563,
                        'specialty_care_routine' => 0.9200000166893005
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
                    'id' => 'vha_689',
                    'lat' => 41.28432479,
                    'long' => -72.95730126,
                    'mobile' => false,
                    'name' => 'West Haven VA Medical Center',
                    'operating_status' => {
                      'code' => 'NORMAL'
                    },
                    'phone' => {
                      'fax' => '203-937-3868',
                      'main' => '203-932-5711',
                      'pharmacy' => '860-667-6750',
                      'after_hours' => '203-932-5711 x3131',
                      'patient_advocate' => '203-937-3877',
                      'mental_health_clinic' => '203-932-5711 x 2570',
                      'enrollment_coordinator' => '203-932-5711 x4246'
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
                        WomensHealth
                      ],
                      'last_updated' => '2020-07-27'
                    },
                    'unique_id' => '689',
                    'visn' => '1',
                    'website' => 'https://www.connecticut.va.gov/locations/directions.asp'
                  }
                },
                {
                  'id' => 'vha_542',
                  'type' => 'facility',
                  'attributes' => {
                    'access' => {
                      'health' => [
                        {
                          'service' => 'Audiology',
                          'new' => 16.25,
                          'established' => 1.083333
                        },
                        {
                          'service' => 'Gynecology',
                          'new' => 83.333333,
                          'established' => 0.0
                        },
                        {
                          'service' => 'MentalHealthCare',
                          'new' => 7.90909,
                          'established' => 2.996632
                        },
                        {
                          'service' => 'Optometry',
                          'new' => 8.714285,
                          'established' => 6.458515
                        },
                        {
                          'service' => 'Orthopedics',
                          'new' => 15.6,
                          'established' => 7.0
                        },
                        {
                          'service' => 'PrimaryCare',
                          'new' => 15.647058,
                          'established' => 1.120622
                        },
                        {
                          'service' => 'SpecialtyCare',
                          'new' => 12.903225,
                          'established' => 5.359633
                        },
                        {
                          'service' => 'Urology',
                          'new' => nil,
                          'established' => 0.0
                        }
                      ],
                      'effective_date' => '2020-07-27'
                    },
                    'active_status' => 'A',
                    'address' => {
                      'mailing' => {
                      },
                      'physical' => {
                        'zip' => '19320-2096',
                        'city' => 'Coatesville',
                        'state' => 'PA',
                        'address_1' => '1400 Black Horse Hill Road',
                        'address_2' => nil,
                        'address_3' => nil
                      }
                    },
                    'classification' => 'VA Medical Center (VAMC)',
                    'facility_type' => 'va_health_facility',
                    'feedback' => {
                      'health' => {
                        'primary_care_urgent' => 0.8399999737739563,
                        'primary_care_routine' => 0.9700000286102295,
                        'specialty_care_urgent' => 0.8299999833106995,
                        'specialty_care_routine' => 0.9300000071525574
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
                    'id' => 'vha_542',
                    'lat' => 39.998097,
                    'long' => -75.7963125,
                    'mobile' => false,
                    'name' => 'Coatesville VA Medical Center',
                    'operating_status' => {
                      'code' => 'NORMAL'
                    },
                    'phone' => {
                      'fax' => '610-383-0248',
                      'main' => '610-384-7711',
                      'pharmacy' => '800-290-6172',
                      'after_hours' => '610-383-0290',
                      'patient_advocate' => '610-384-7711 x2103',
                      'mental_health_clinic' => '610-384-7711 x 4918',
                      'enrollment_coordinator' => '610-383-0266'
                    },
                    'services' => {
                      'other' => [],
                      'health' => %w[
                        Audiology
                        DentalServices
                        Gynecology
                        MentalHealthCare
                        Nutrition
                        Optometry
                        Orthopedics
                        Podiatry
                        PrimaryCare
                        SpecialtyCare
                        UrgentCare
                        Urology
                      ],
                      'last_updated' => '2020-07-27'
                    },
                    'unique_id' => '542',
                    'visn' => '4',
                    'website' => 'https://www.coatesville.va.gov/locations/directions.asp'
                  }
                },
                {
                  'id' => 'vha_689A4',
                  'type' => 'facility',
                  'attributes' => {
                    'access' => {
                      'health' => [
                        {
                          'service' => 'Audiology',
                          'new' => 3.237288,
                          'established' => 1.447368
                        },
                        {
                          'service' => 'Cardiology',
                          'new' => 20.0,
                          'established' => 12.163265
                        },
                        {
                          'service' => 'Dermatology',
                          'new' => 5.15,
                          'established' => 8.788461
                        },
                        {
                          'service' => 'Gynecology',
                          'new' => 15.25,
                          'established' => 14.0
                        },
                        {
                          'service' => 'MentalHealthCare',
                          'new' => 6.166666,
                          'established' => 2.442307
                        },
                        {
                          'service' => 'Ophthalmology',
                          'new' => 3.0,
                          'established' => 8.466666
                        },
                        {
                          'service' => 'Optometry',
                          'new' => 6.727272,
                          'established' => 1.186256
                        },
                        {
                          'service' => 'PrimaryCare',
                          'new' => 9.0,
                          'established' => 3.810309
                        },
                        {
                          'service' => 'SpecialtyCare',
                          'new' => 12.875846,
                          'established' => 10.416932
                        },
                        {
                          'service' => 'Urology',
                          'new' => 26.565217,
                          'established' => 14.492647
                        }
                      ],
                      'effective_date' => '2020-07-27'
                    },
                    'active_status' => 'A',
                    'address' => {
                      'mailing' => {
                      },
                      'physical' => {
                        'zip' => '06111-2631',
                        'city' => 'Newington',
                        'state' => 'CT',
                        'address_1' => '555 Willard Avenue',
                        'address_2' => nil,
                        'address_3' => nil
                      }
                    },
                    'classification' => 'Multi-Specialty CBOC',
                    'facility_type' => 'va_health_facility',
                    'feedback' => {
                      'health' => {
                        'primary_care_urgent' => 0.8700000047683716,
                        'primary_care_routine' => 0.9800000190734863
                      },
                      'effective_date' => '2020-04-16'
                    },
                    'hours' => {
                      'friday' => '700AM-430PM',
                      'monday' => '700AM-430PM',
                      'sunday' => 'Closed',
                      'tuesday' => '700AM-430PM',
                      'saturday' => 'Closed',
                      'thursday' => '700AM-430PM',
                      'wednesday' => '700AM-430PM'
                    },
                    'id' => 'vha_689A4',
                    'lat' => 41.702148,
                    'long' => -72.737856,
                    'mobile' => false,
                    'name' => 'Newington VA Clinic',
                    'operating_status' => {
                      'code' => 'NORMAL'
                    },
                    'phone' => {
                      'fax' => '860-667-6764',
                      'main' => '860-666-6951',
                      'pharmacy' => '860-667-6750',
                      'after_hours' => '203-932-5711 x3131',
                      'patient_advocate' => '203-937-3877',
                      'mental_health_clinic' => '860-666-6951 x 6763',
                      'enrollment_coordinator' => '203-932-5711 x4246'
                    },
                    'services' => {
                      'other' => [],
                      'health' => %w[
                        Audiology
                        Cardiology
                        DentalServices
                        Dermatology
                        Gynecology
                        MentalHealthCare
                        Nutrition
                        Ophthalmology
                        Optometry
                        Podiatry
                        PrimaryCare
                        SpecialtyCare
                        UrgentCare
                        Urology
                      ],
                      'last_updated' => '2020-07-27'
                    },
                    'unique_id' => '689A4',
                    'visn' => '1',
                    'website' => 'https://www.connecticut.va.gov/locations/Newington_Campus.asp'
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
                  },
                  'relationships' => {
                    'specialties' => {
                      'data' => []
                    }
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
                  },
                  'relationships' => {
                    'specialties' => {
                      'data' => []
                    }
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
                  },
                  'relationships' => {
                    'specialties' => {
                      'data' => []
                    }
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
                  },
                  'relationships' => {
                    'specialties' => {
                      'data' => []
                    }
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
                  },
                  'relationships' => {
                    'specialties' => {
                      'data' => []
                    }
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
                  },
                  'relationships' => {
                    'specialties' => {
                      'data' => []
                    }
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
                  },
                  'relationships' => {
                    'specialties' => {
                      'data' => []
                    }
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
                  },
                  'relationships' => {
                    'specialties' => {
                      'data' => []
                    }
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
                  },
                  'relationships' => {
                    'specialties' => {
                      'data' => []
                    }
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
                  },
                  'relationships' => {
                    'specialties' => {
                      'data' => []
                    }
                  }
                }
              ]
            }
          )
        end
      end
    end
  end
end
