# frozen_string_literal: true

require 'lighthouse/facilities/facility'

FactoryBot.define do
  factory :lighthouse_facility, class: Lighthouse::Facilities::Facility do
    # vha_648A4
    transient do
      access do
        {
          health: [
            {
              service: 'Audiology',
              new: Faker::Number.decimal(l_digits: 2),
              established: Faker::Number.decimal(l_digits: 2, r_digits: 1)
            },
            {
              service: 'Dermatology',
              new: Faker::Number.decimal(l_digits: 2, r_digits: 1),
              established: Faker::Number.decimal(l_digits: 2, r_digits: 1)
            },
            {
              service: 'MentalHealthCare',
              new: Faker::Number.decimal(l_digits: 2, r_digits: 1),
              established: Faker::Number.decimal(l_digits: 2, r_digits: 1)
            },
            {
              service: 'Ophthalmology',
              new: Faker::Number.decimal(l_digits: 2, r_digits: 1),
              established: Faker::Number.decimal(l_digits: 2, r_digits: 1)
            },
            {
              service: 'Optometry',
              new: Faker::Number.decimal(l_digits: 2, r_digits: 1),
              established: Faker::Number.decimal(l_digits: 2, r_digits: 1)
            },
            {
              service: 'PrimaryCare',
              new: Faker::Number.decimal(l_digits: 2, r_digits: 1),
              established: Faker::Number.decimal(l_digits: 2, r_digits: 1)
            },
            {
              service: 'SpecialtyCare',
              new: Faker::Number.decimal(l_digits: 2, r_digits: 1),
              established: Faker::Number.decimal(l_digits: 2, r_digits: 1)
            }
          ],
          effective_date: Faker::Date.between(from: 2.months.ago, to: 1.day.ago)
        }
      end
      active_status { 'A' }
      address do
        {
          mailing: {},
          physical: {
            zip: '98661-3753',
            city: 'Vancouver',
            state: 'WA',
            address_1: '1601 East 4th Plain Boulevard',
            address_2: nil,
            address_3: nil
          }
        }
      end
      classification { 'VA Medical Center (VAMC)' }
      facility_type { 'va_health_facility' }
      feedback do
        {
          health: {
            primary_care_urgent: Faker::Number.decimal(l_digits: 0, r_digits: 2),
            primary_care_routine: Faker::Number.decimal(l_digits: 0, r_digits: 2)
          },
          effective_date: Faker::Date.between(from: 2.months.ago, to: 1.day.ago)
        }
      end
      hours do
        {
          monday: '730AM-430PM',
          tuesday: '730AM-630PM',
          wednesday: '730AM-430PM',
          thursday: '730AM-430PM',
          friday: '730AM-430PM',
          saturday: 'Closed',
          sunday: 'Closed'
        }
      end
      id { 'vha_648A4' }
      lat { 45.63942553000004 }
      long { -122.65533567999995 }
      mobile { false }
      name { 'Portland VA Medical Center-Vancouver' }
      operating_status do
        {
          'code' => 'NORMAL'
        }
      end
      phone do
        {
          fax: '360-690-0864',
          main: '360-759-1901',
          pharmacy: '503-273-5183',
          after_hours: '360-696-4061',
          patient_advocate: '503-273-5308',
          mental_health_clinic: '503-273-5187',
          enrollment_coordinator: '503-273-5069'
        }
      end
      services do
        {
          other: [],
          health: %w[
            Audiology DentalServices Dermatology EmergencyCare
            MentalHealthCare Nutrition Ophthalmology Optometry
            Podiatry PrimaryCare SpecialtyCare
          ]
        }
      end
      visn { '20' }
      website { 'https://www.portland.va.gov/locations/vancouver.asp' }
    end

    initialize_with do
      Lighthouse::Facilities::Facility.new(
        {
          'id' => id,
          'type' => 'va_facilities',
          'attributes' => {
            'active_status' => active_status,
            'address' => address,
            'classification' => classification,
            'facility_type' => facility_type,
            'hours' => hours,
            'lat' => lat,
            'long' => long,
            'mobile' => mobile,
            'name' => name,
            'operating_status' => operating_status,
            'phone' => phone,
            'satisfaction' => feedback,
            'services' => services,
            'visn' => visn,
            'wait_times' => access,
            'website' => website
          }
        }
      )
    end
  end
end
