# frozen_string_literal: true

require 'rails_helper'

vcr_options = {
  cassette_name: 'facilities/va/ppms_and_lighthouse',
  match_requests_on: %i[path query],
  allow_playback_repeats: true
}

RSpec.describe 'VA and Community Care Mashup', type: :request, team: :facilities, vcr: vcr_options do
  describe '#index' do
    context 'type=urgent_care' do
      let(:path) { '/v1/facilities/va_ccp/urgent_care' }

      let(:params) do
        {
          address: '58 Leonard Ave, Leonardo, NJ 07737',
          bbox: ['-75.877', '38.543', '-72.240', '42.236'],
          per_page: 10
        }
      end

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
                        'id' => 'b190bc4fc5a8f9e8633df1bef4fcdfa4081b40ba1c92e6151b31441e50f91dbb',
                        'type' => 'provider'
                      },
                      {
                        'id' => '58c6acd75b174903d6aae7284567f007962f1c3588ba98725018a1ca48e3054b',
                        'type' => 'provider'
                      },
                      {
                        'id' => '23b9ba9fd9c5b55d149163e1bf325a3eafe6b550f97987b6153cc485b8472265',
                        'type' => 'provider'
                      },
                      {
                        'id' => '021c84f43edddbe11cd5784f9d4fdfaab92ce5f24bbc8cc69e66e3bf3336073d',
                        'type' => 'provider'
                      },
                      {
                        'id' => 'acb595132b8f22416153086a5ebdd7dfc6bd7da56965ac5d1a18374b3e1901a8',
                        'type' => 'provider'
                      },
                      {
                        'id' => 'c8ea0e2d8f21a0628d3900d919c9933f3d0378f8ea19faefd70a77466054f70d',
                        'type' => 'provider'
                      },
                      {
                        'id' => '9d74be207e16b6e2dc26a94e944533b692c64a2ee7213c812471a4aa6adf7cb9',
                        'type' => 'provider'
                      },
                      {
                        'id' => 'a64612810c102e0a6ff7b4099ecd50032c5be9e0a60004e166bcb61814628522',
                        'type' => 'provider'
                      },
                      {
                        'id' => '22f324d93d93eb39fce95c702a7967a2aa8a111a6f2b7973671c63431ef741b1',
                        'type' => 'provider'
                      },
                      {
                        'id' => 'c4939eac9bea3d6bac7477b7228a632233f853851463169828d04c8580817b50',
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
                'id' => 'b190bc4fc5a8f9e8633df1bef4fcdfa4081b40ba1c92e6151b31441e50f91dbb',
                'type' => 'provider',
                'attributes' => {
                  'acc_new_patients' => 'true',
                  'address' => {
                    'street' => '363 STATE ROUTE 36',
                    'city' => 'PORT MONMOUTH',
                    'state' => 'NJ',
                    'zip' => '07758-1359'
                  },
                  'caresite_phone' => '732-471-0400',
                  'email' => nil,
                  'fax' => nil,
                  'gender' => 'NotSpecified',
                  'lat' => 40.428809,
                  'long' => -74.10675,
                  'name' => 'MINUTE CLINIC',
                  'phone' => nil,
                  'pos_codes' => '20',
                  'pref_contact' => nil,
                  'unique_id' => '1427432244'
                },
                'relationships' => {
                  'specialties' => {
                    'data' => []
                  }
                }
              },
              {
                'id' => '58c6acd75b174903d6aae7284567f007962f1c3588ba98725018a1ca48e3054b',
                'type' => 'provider',
                'attributes' => {
                  'acc_new_patients' => 'false',
                  'address' => {
                    'street' => '470 STATE ROUTE 36',
                    'city' => 'HIGHLANDS',
                    'state' => 'NJ',
                    'zip' => '07732-1315'
                  },
                  'caresite_phone' => '866-389-2727',
                  'email' => nil,
                  'fax' => nil,
                  'gender' => 'NotSpecified',
                  'lat' => 40.405653,
                  'long' => -74.004139,
                  'name' => 'MINUTECLINIC LOCATED INSIDE CVS',
                  'phone' => nil,
                  'pos_codes' => '17',
                  'pref_contact' => nil,
                  'unique_id' => '1053353615'
                },
                'relationships' => {
                  'specialties' => {
                    'data' => []
                  }
                }
              },
              {
                'id' => '23b9ba9fd9c5b55d149163e1bf325a3eafe6b550f97987b6153cc485b8472265',
                'type' => 'provider',
                'attributes' => {
                  'acc_new_patients' => 'true',
                  'address' => {
                    'street' => '41 RECKLESS PL',
                    'city' => 'RED BANK',
                    'state' => 'NJ',
                    'zip' => '07701-1703'
                  },
                  'caresite_phone' => '315-637-7878',
                  'email' => nil,
                  'fax' => nil,
                  'gender' => 'NotSpecified',
                  'lat' => 40.34667,
                  'long' => -74.06695,
                  'name' => 'NORTH MEDICAL URGENT CARE',
                  'phone' => nil,
                  'pos_codes' => '20',
                  'pref_contact' => nil,
                  'unique_id' => '1942501747'
                },
                'relationships' => {
                  'specialties' => {
                    'data' => []
                  }
                }
              },
              {
                'id' => '021c84f43edddbe11cd5784f9d4fdfaab92ce5f24bbc8cc69e66e3bf3336073d',
                'type' => 'provider',
                'attributes' => {
                  'acc_new_patients' => 'false',
                  'address' => {
                    'street' => '46 NEWMAN SPRINGS RD E STE F',
                    'city' => 'RED BANK',
                    'state' => 'NJ',
                    'zip' => '07701-1531'
                  },
                  'caresite_phone' => '732-281-3201',
                  'email' => nil,
                  'fax' => nil,
                  'gender' => 'NotSpecified',
                  'lat' => 40.338489,
                  'long' => -74.065758,
                  'name' => 'IMMEDIATE CARE MEDICAL WALK IN RED BANK',
                  'phone' => nil,
                  'pos_codes' => '20',
                  'pref_contact' => nil,
                  'unique_id' => '1447622402'
                },
                'relationships' => {
                  'specialties' => {
                    'data' => []
                  }
                }
              },
              {
                'id' => 'acb595132b8f22416153086a5ebdd7dfc6bd7da56965ac5d1a18374b3e1901a8',
                'type' => 'provider',
                'attributes' => {
                  'acc_new_patients' => 'false',
                  'address' => {
                    'street' => '2880 STATE ROUTE 35',
                    'city' => 'HAZLET',
                    'state' => 'NJ',
                    'zip' => '07730-1504'
                  },
                  'caresite_phone' => '732-888-1238',
                  'email' => nil,
                  'fax' => nil,
                  'gender' => 'NotSpecified',
                  'lat' => 40.416926,
                  'long' => -74.17347,
                  'name' => 'MEDEXPRESS URGENT CARE NEW JERSEY',
                  'phone' => nil,
                  'pos_codes' => '20',
                  'pref_contact' => nil,
                  'unique_id' => '1205183894'
                },
                'relationships' => {
                  'specialties' => {
                    'data' => []
                  }
                }
              },
              {
                'id' => 'c8ea0e2d8f21a0628d3900d919c9933f3d0378f8ea19faefd70a77466054f70d',
                'type' => 'provider',
                'attributes' => {
                  'acc_new_patients' => 'true',
                  'address' => {
                    'street' => '3253 STATE ROUTE 35 STE 2',
                    'city' => 'HAZLET',
                    'state' => 'NJ',
                    'zip' => '07730-1544'
                  },
                  'caresite_phone' => '732-888-7646',
                  'email' => nil,
                  'fax' => nil,
                  'gender' => 'NotSpecified',
                  'lat' => 40.422501,
                  'long' => -74.187784,
                  'name' => 'MINUTE CLINIC',
                  'phone' => nil,
                  'pos_codes' => '20',
                  'pref_contact' => nil,
                  'unique_id' => '1427432244'
                },
                'relationships' => {
                  'specialties' => {
                    'data' => []
                  }
                }
              },
              {
                'id' => '9d74be207e16b6e2dc26a94e944533b692c64a2ee7213c812471a4aa6adf7cb9',
                'type' => 'provider',
                'attributes' => {
                  'acc_new_patients' => 'false',
                  'address' => {
                    'street' => '3391 STATE ROUTE 35',
                    'city' => 'HAZLET',
                    'state' => 'NJ',
                    'zip' => '07730-1521'
                  },
                  'caresite_phone' => '866-389-2727',
                  'email' => nil,
                  'fax' => nil,
                  'gender' => 'NotSpecified',
                  'lat' => 40.423831,
                  'long' => -74.193929,
                  'name' => 'MINUTECLINIC LOCATED INSIDE CVS',
                  'phone' => nil,
                  'pos_codes' => '17',
                  'pref_contact' => nil,
                  'unique_id' => '1053353615'
                },
                'relationships' => {
                  'specialties' => {
                    'data' => []
                  }
                }
              },
              {
                'id' => 'a64612810c102e0a6ff7b4099ecd50032c5be9e0a60004e166bcb61814628522',
                'type' => 'provider',
                'attributes' => {
                  'acc_new_patients' => 'false',
                  'address' => {
                    'street' => '30 SHREWSBURY PLZ',
                    'city' => 'SHREWSBURY',
                    'state' => 'NJ',
                    'zip' => '07702-4322'
                  },
                  'caresite_phone' => '732-542-0002',
                  'email' => nil,
                  'fax' => nil,
                  'gender' => 'NotSpecified',
                  'lat' => 40.31595033,
                  'long' => -74.064036,
                  'name' => 'MINUTE CLINIC',
                  'phone' => nil,
                  'pos_codes' => '20',
                  'pref_contact' => nil,
                  'unique_id' => '1649252776'
                },
                'relationships' => {
                  'specialties' => {
                    'data' => []
                  }
                }
              },
              {
                'id' => '22f324d93d93eb39fce95c702a7967a2aa8a111a6f2b7973671c63431ef741b1',
                'type' => 'provider',
                'attributes' => {
                  'acc_new_patients' => 'true',
                  'address' => {
                    'street' => '30 SHREWSBURY PLZ',
                    'city' => 'SHREWSBURY',
                    'state' => 'NJ',
                    'zip' => '07702-4322'
                  },
                  'caresite_phone' => '732-542-0002',
                  'email' => nil,
                  'fax' => nil,
                  'gender' => 'NotSpecified',
                  'lat' => 40.31595033,
                  'long' => -74.064036,
                  'name' => 'MINUTE CLINIC',
                  'phone' => nil,
                  'pos_codes' => '20',
                  'pref_contact' => nil,
                  'unique_id' => '1427432244'
                },
                'relationships' => {
                  'specialties' => {
                    'data' => []
                  }
                }
              },
              {
                'id' => 'c4939eac9bea3d6bac7477b7228a632233f853851463169828d04c8580817b50',
                'type' => 'provider',
                'attributes' => {
                  'acc_new_patients' => 'true',
                  'address' => {
                    'street' => '1140 STATE ROUTE 34',
                    'city' => 'ABERDEEN',
                    'state' => 'NJ',
                    'zip' => '07747-2167'
                  },
                  'caresite_phone' => '732-583-5100',
                  'email' => nil,
                  'fax' => nil,
                  'gender' => 'NotSpecified',
                  'lat' => 40.39652,
                  'long' => -74.224742,
                  'name' => 'DOCTORS EXPRESS',
                  'phone' => nil,
                  'pos_codes' => '20',
                  'pref_contact' => nil,
                  'unique_id' => '1851733349'
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
