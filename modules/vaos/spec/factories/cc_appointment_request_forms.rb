# frozen_string_literal: true

FactoryBot.define do
  factory :cc_appointment_request_form, class: 'VAOS::CCAppointmentRequestForm' do
    transient do
      user { build(:user, :vaos) }
    end

    initialize_with { new(user, attributes) }

    trait :creation do
      additional_information { 'Whatever' }
      address { '' } # Why is this not required?
      appointment_type { 'Primary Care' }
      best_timeto_call { %w[Morning Afternoon Evening] }
      cc_appointment_request { {} } # What is this and why is it ok that it be empty?
      city { '' } # What?
      state { '' } # What?
      zip_code { '' } # What?
      distance_willing_to_travel { '25' } # so it it a string or an integer??
      email { 'abraham.lincoln@va.gov' }
      new_message { 'A message to a clerk' }
      office_hours { %w[Weekdays Evenings Weekends] }
      option_date1 { '1/20/2020' }
      option_time1 { 'AM' }
      option_date2 { 'No Date Selected' }
      option_time2 { 'No Time Selected' }
      option_date3 { 'No Date Selected' }
      option_time3 { 'No Time Selected' }

      text_messaging_allowed { false }
      phone_number { '(111) 111-1111' }
      preferred_city { 'A city' }
      preferred_state { 'ME' }
      preferred_zip_code { '11111' }
      provider_id { '0' }
      provider_option { 'Call before booking appointment' }
      preferred_language { 'English' }
      purpose_of_visit { 'Routine Follow-up' }
      reason_for_visit { '' } # What is the purpose of this attribute? Looks like a duplicate of purpose of visit
      requested_phone_call { false }
      service { 'Community Care Appointments (You may be eligible for Care in the Community)' }
      type_of_care_id { 'CCAUDHEAR' }
      visit_type { 'Office Visit' }

      facility do
        {
          name: 'CHYSHR-CHEYENNE VAMC',
          type: 'M&ROC',
          facility_code: '983',
          state: 'WY',
          city: 'CHEYENNE',
          address: '2360 EAST PERSHING BLVD',
          parent_site_code: '983',
          supports_v_a_r: true,
          children: [
            {
              name: 'CHYSHR-SIDNEY CBOC',
              type: 'CBOC',
              facility_code: '983GB',
              state: 'NE',
              city: 'SIDNEY',
              address: '1116 10TH ST',
              parent_site_code: '983'
            },
            {
              name: 'CHYSHR-FORT COLLINS',
              type: 'CBOC',
              facility_code: '983GC',
              state: 'CO',
              city: 'FORT COLLINS',
              address: '2509 RESEARCH BLVD',
              parent_site_code: '983'
            },
            {
              name: 'CHYSHR-GREELEY CBOC',
              type: 'CBOC',
              facility_code: '983GD',
              state: 'CO',
              city: 'GREELEY',
              address: '2001 70TH AVE #200',
              parent_site_code: '983'
            }
          ]
        }
      end

      preferred_providers do
        [
          {
            id: 1,
            firstName: 'Joe',
            lastName: 'Provider',
            practiceName: 'Some practice',
            providerStreet: '123 Big sky st',
            address: {
              street: '',
              city: '',
              state: '',
              zipCode: '11222'
            },
            providerCity: 'Northampton',
            providerState: 'LA',
            providerZipCode1: '11222'
          }
        ]
      end

      patient do
        {
          inpatient: false,
          text_messaging_allowed: false
        }
      end
    end

    trait :cancellation do
      creation

      appointment_request_detail_code { ['DETCODE8'] }
      status { 'Cancelled' }
    end
  end
end
