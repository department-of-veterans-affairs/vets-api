# frozen_string_literal: true

require 'rails_helper'

vcr_options = {
  cassette_name: 'facilities/va/ppms_and_lighthouse',
  match_requests_on: %i[path query],
  allow_playback_repeats: true
}

RSpec.describe 'VA and Community Care Mashup', team: :facilities, vcr: vcr_options do
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

        expect(bod['data']).to include(
          {
            'id' => '927d31eb-11fd-43c2-ac29-11c1a4128819',
            'type' => 'providerFacility',
            'relationships' => {
              'providers' => {
                'data' => [
                  {
                    'id' =>
                    '1a2ec66b370936eccc980db2fcf4b094fc61a5329aea49744d538f6a9bab2569',
                    'type' => 'provider'
                  },
                  {
                    'id' =>
                    '9424b96e29042c27843708f7f3272813da91439bdfc59ac6ff15199d49050b95',
                    'type' => 'provider'
                  },
                  {
                    'id' =>
                    '0945d76221cda6f695abd1be1b0a69d8d424a91c57391ec650bb237a9b618729',
                    'type' => 'provider'
                  },
                  {
                    'id' =>
                    'bec5a55684b934d859c6090810735965a07dfe9135fe51404e49f4dec51eafaa',
                    'type' => 'provider'
                  },
                  {
                    'id' =>
                    '586ad0a071e8ac2736ccf4a434d61f98b8ac5633c64ac13a654c5dd78450114d',
                    'type' => 'provider'
                  },
                  {
                    'id' =>
                    '671ecd71f4d2b7d600a3d2343205e2196255e80269d696bd396991361b593a34',
                    'type' => 'provider'
                  },
                  {
                    'id' =>
                    '0bf256c9c6c9592a34d0f82922acdb1655dae964b487473effbf2c1881d1bc19',
                    'type' => 'provider'
                  },
                  {
                    'id' =>
                    '724d059658cbf067586f493d474f282e69dc695302e964abaac3bd715599f2e3',
                    'type' => 'provider'
                  },
                  {
                    'id' =>
                    '5b3dc91323efc8cd314776cb6b1c7aef17410d3aef5ba4b26cd16f6c2cef102e',
                    'type' => 'provider'
                  },
                  {
                    'id' =>
                    'd2e4b7b1c751b29c0036f08d7e5c4d539a8985fa71513f7c4ba89c973383d197',
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
                    'id' => 'vha_561A4',
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
        )

        expect(bod['included'][0]).to match(
          {
            'id' => 'vha_561',
            'type' => 'facility',
            'attributes' => {
              'access' => {
                'health' => [
                  {
                    'service' => 'Audiology',
                    'new' => 31.161971,
                    'established' => 28.495652
                  },
                  {
                    'service' => 'Cardiology',
                    'new' => 51.1875,
                    'established' => 27.459574
                  },
                  {
                    'service' => 'Dermatology',
                    'new' => 19.928571,
                    'established' => 4.674757
                  },
                  {
                    'service' => 'Gastroenterology',
                    'new' => 25.939393,
                    'established' => 27.321428
                  },
                  {
                    'service' => 'Gynecology',
                    'new' => 24.571428,
                    'established' => 9.047619
                  },
                  {
                    'service' => 'MentalHealthCare',
                    'new' => 5.34375,
                    'established' => 3.962011
                  },
                  {
                    'service' => 'Ophthalmology',
                    'new' => 24.222222,
                    'established' => 36.638069
                  },
                  {
                    'service' => 'Optometry',
                    'new' => 26.722222,
                    'established' => 41.70045
                  },
                  {
                    'service' => 'Orthopedics',
                    'new' => 9.056603,
                    'established' => 0.725
                  },
                  {
                    'service' => 'PrimaryCare',
                    'new' => 14.436363,
                    'established' => 14.335578
                  },
                  {
                    'service' => 'SpecialtyCare',
                    'new' => 17.562446,
                    'established' => 16.47847
                  },
                  {
                    'service' => 'Urology',
                    'new' => 20.5,
                    'established' => 8.352941
                  }
                ],
                'effectiveDate' => '2021-06-07'
              },
              'activeStatus' => 'A',
              'address' => {
                'mailing' => {},
                'physical' => {
                  'zip' => '07018-1023',
                  'city' => 'East Orange',
                  'state' => 'NJ',
                  'address1' => '385 Tremont Avenue',
                  'address2' => nil,
                  'address3' => nil
                }
              },
              'classification' => 'VA Medical Center (VAMC)',
              'detailedServices' => [
                {
                  'name' => 'COVID-19 vaccines',
                  'descriptionFacility' => nil,
                  'appointmentLeadin' =>
                  '<p><em>&nbsp; &nbsp;Contact us to schedule, reschedule, or cancel your appointment. If a ' \
                    'referral is required, you’ll need to contact your primary care provider first.</em></p>',
                  'appointmentPhones' => [
                    {
                      'extension' => nil,
                      'label' => 'Main phone',
                      'number' => '973-676-1000',
                      'type' => 'tel'
                    }
                  ],
                  'onlineSchedulingAvailable' => nil,
                  'referralRequired' => nil,
                  'walkInsAccepted' => nil,
                  'serviceLocations' => nil,
                  'path' =>
                  'https://www.newjersey.va.gov/services/covid-19-vaccines.asp'
                }
              ],
              'facilityType' => 'va_health_facility',
              'feedback' => {
                'health' => {
                  'primaryCareUrgent' => 0.6200000047683716,
                  'primaryCareRoutine' => 0.8100000023841858,
                  'specialtyCareUrgent' => 0.7799999713897705,
                  'specialtyCareRoutine' => 0.8500000238418579
                },
                'effectiveDate' => '2021-03-05'
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
              'operatingStatus' => {
                'code' => 'NORMAL'
              },
              'operationalHoursSpecialInstructions' =>
                            'Normal business hours are Monday through Friday, 8:00 a.m. to 4:30 p.m. |',
              'phone' => {
                'fax' => '973-676-4226',
                'main' => '973-676-1000',
                'pharmacy' => '800-480-5590',
                'afterHours' => '973-676-1000',
                'patientAdvocate' => '973-676-1000 x203399',
                'mentalHealthClinic' => '973-676-1000 x 1421',
                'enrollmentCoordinator' => '973-676-1000 x203044'
              },
              'services' => {
                'other' => [],
                'health' => %w[Audiology Cardiology CaregiverSupport Covid19Vaccine DentalServices Dermatology
                               EmergencyCare Gastroenterology Gynecology MentalHealthCare Nutrition Ophthalmology
                               Optometry Orthopedics Podiatry PrimaryCare SpecialtyCare UrgentCare Urology],
                'lastUpdated' => '2021-06-07'
              },
              'uniqueId' => '561',
              'visn' => '2',
              'website' => 'https://www.newjersey.va.gov/locations/directions.asp'
            }
          }
        )

        expect(bod['included']).to include(
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
              'posCodes' => '17',
              'prefContact' => nil,
              'uniqueId' => '1225028293'
            }
          }
        )
      end
    end
  end
end
