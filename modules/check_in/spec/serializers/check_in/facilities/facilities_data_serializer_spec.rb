# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CheckIn::Facilities::FacilitiesDataSerializer do
  subject { described_class }

  let(:facilities_data) do
    {
      id: '442',
      facilitiesApiId: 'vha_442',
      vistaSite: '442',
      vastParent: '442',
      type: 'va_health_facility',
      name: 'Cheyenne VA Medical Center',
      classification: 'VA Medical Center (VAMC)',
      timezone: {
        timeZoneId: 'America/Denver'
      },
      lat: 41.148026,
      long: -104.786255,
      website: 'https://www.va.gov/cheyenne-health-care/locations/cheyenne-va-medical-center/',
      phone: {
        main: '307-778-7550',
        fax: '307-778-7381',
        pharmacy: '866-420-6337',
        afterHours: '307-778-7550',
        patientAdvocate: '307-778-7550 x7573',
        mentalHealthClinic: '307-778-7349',
        enrollmentCoordinator: '307-778-7550 x7579'
      },
      mailingAddress: {
        type: 'postal',
        line: [nil, nil, nil]
      },
      physicalAddress: {
        type: 'physical',
        line: ['2360 East Pershing Boulevard', nil, nil],
        city: 'Cheyenne',
        state: 'WY',
        postalCode: '82001-5356'
      },
      mobile: false,
      healthService: %w[Audiology Cardiology CaregiverSupport Covid19Vaccine DentalServices Dermatology EmergencyCare
                        Gastroenterology Gynecology MentalHealthCare Nutrition Ophthalmology Optometry Orthopedics
                        Podiatry PrimaryCare Urology WomensHealth],
      operatingStatus: {
        code: 'NORMAL'
      },
      visn: '19'
    }
  end

  describe '#serializable_hash' do
    context 'when all the necessary fields exist' do
      let(:serialized_hash_response) do
        {
          data: {
            id: '442',
            type: :facilities_data,
            attributes: {
              type: 'va_health_facility',
              name: 'Cheyenne VA Medical Center',
              classification: 'VA Medical Center (VAMC)',
              timezone: {
                timeZoneId: 'America/Denver'
              },
              phone: {
                main: '307-778-7550',
                fax: '307-778-7381',
                pharmacy: '866-420-6337',
                afterHours: '307-778-7550',
                patientAdvocate: '307-778-7550 x7573',
                mentalHealthClinic: '307-778-7349',
                enrollmentCoordinator: '307-778-7550 x7579'
              },
              physicalAddress: {
                type: 'physical',
                line: ['2360 East Pershing Boulevard', nil, nil],
                city: 'Cheyenne',
                state: 'WY',
                postalCode: '82001-5356'
              }
            }
          }
        }
      end

      it 'returns a serialized hash' do
        facilities_struct = OpenStruct.new(facilities_data)
        facilities_serializer = CheckIn::Facilities::FacilitiesDataSerializer.new(facilities_struct)

        expect(facilities_serializer.serializable_hash).to eq(serialized_hash_response)
      end
    end

    context 'when name does not exist' do
      let(:facilities_data_without_name) do
        facilities_data.except!(:name)
        facilities_data
      end

      let(:serialized_hash_response) do
        {
          data: {
            id: '442',
            type: :facilities_data,
            attributes: {
              name: nil,
              type: 'va_health_facility',
              classification: 'VA Medical Center (VAMC)',
              timezone: {
                timeZoneId: 'America/Denver'
              },
              phone: {
                main: '307-778-7550',
                fax: '307-778-7381',
                pharmacy: '866-420-6337',
                afterHours: '307-778-7550',
                patientAdvocate: '307-778-7550 x7573',
                mentalHealthClinic: '307-778-7349',
                enrollmentCoordinator: '307-778-7550 x7579'
              },
              physicalAddress: {
                type: 'physical',
                line: ['2360 East Pershing Boulevard', nil, nil],
                city: 'Cheyenne',
                state: 'WY',
                postalCode: '82001-5356'
              }
            }
          }
        }
      end

      it 'returns a serialized hash with nil in name field' do
        facilities_struct = OpenStruct.new(facilities_data_without_name)
        facilities_serializer = CheckIn::Facilities::FacilitiesDataSerializer.new(facilities_struct)

        expect(facilities_serializer.serializable_hash).to eq(serialized_hash_response)
      end
    end
  end
end
