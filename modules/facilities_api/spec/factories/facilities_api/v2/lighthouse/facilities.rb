# frozen_string_literal: true

require 'lighthouse/facilities/facility'

FactoryBot.define do
  factory :facilities_api_v2_lighthouse_facility, class: 'FacilitiesApi::V2::Lighthouse::Facility' do
    transient do
      access do
        {
          health: [],
          effective_date: ''
        }
      end
      address do
        {
          physical: {
            zip: '98661-3753',
            city: 'Vancouver',
            state: 'WA',
            address1: '1601 East 4th Plain Boulevard'
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
      operational_hours_special_instructions do
        [
          'More hours are available for some services. To learn more, call our main phone number.',
          'If you need to talk to someone or get advice right away, call the Vet Center anytime at 1-877-WAR-VETS ' \
          '(1-877-927-8387).'
        ]
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
          health: [
            {
              name: 'Audiology',
              service_id: 'audiology',
              link: 'https://example.com/services/va_facilities/v1/facilities/vha_648A4/services/audiology'
            },
            {
              name: 'Dermatology',
              service_id: 'dermatology',
              link: 'https://example.com/services/va_facilities/v1/facilities/vha_648A4/services/dermatology'
            },
            {
              name: 'Geriatrics',
              service_id: 'geriatrics',
              link: 'https://example.com/services/va_facilities/v1/facilities/vha_648A4/services/geriatrics'
            },
            {
              name: 'Ophthalmology',
              service_id: 'ophthalmology',
              link: 'https://example.com/services/va_facilities/v1/facilities/vha_648A4/services/ophthalmology'
            },
            {
              name: 'Optometry',
              service_id: 'Optometry',
              link: 'https://example.com/services/va_facilities/v1/facilities/vha_648A4/services/optometry'
            },
            {
              name: 'Primary care',
              service_id: 'primaryCare',
              link: 'https://example.com/services/va_facilities/v1/facilities/vha_648A4/services/primaryCare'
            }
          ],
          link: 'https://example.com/services/va_facilities/v1/facilities/vha_648A4/services',
          last_updated: Faker::Date.between(from: 2.months.ago, to: 1.day.ago)
        }
      end
      visn { '20' }
      website { 'https://www.portland.va.gov/locations/vancouver.asp' }
    end

    initialize_with do
      FacilitiesApi::V2::Lighthouse::Facility.new(
        {
          'id' => id,
          'type' => 'va_facilities',
          'attributes' => {
            'address' => address,
            'classification' => classification,
            'facility_type' => facility_type,
            'hours' => hours,
            'lat' => lat,
            'long' => long,
            'mobile' => mobile,
            'name' => name,
            'operating_status' => operating_status,
            'operational_hours_special_instructions' => operational_hours_special_instructions,
            'phone' => phone,
            'satisfaction' => feedback,
            'services' => services,
            'visn' => visn,
            'website' => website
          }
        }
      )
    end
  end
end
