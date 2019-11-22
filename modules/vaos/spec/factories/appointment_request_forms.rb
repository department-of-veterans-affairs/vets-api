# frozen_string_literal: true

FactoryBot.define do
  factory :appointment_request_form, class: 'VAOS::AppointmentRequestForm' do
    transient do
      user { build(:user, :vaos) }
    end

    initialize_with { new(user, attributes) }

    trait :with_other_attributes do
      email { 'judy.morrison@fake.gov' }
      other_purpose_of_visit { 'MRI' }
      provider_name { 'Abraham Lincoln' }
      surrogate_identifier { {} }
    end

    trait :creation do
      option_date1 { '11/29/2019' }
      option_time1 { 'AM' }
      option_date2 { 'No Date Selected' }
      option_time2 { 'No Time Selected' }
      option_date3 { 'No Date Selected' }
      option_time3 { 'No Time Selected' }
      status { 'Requested' }
      appointment_type { 'Primary Care' }
      visit_type { 'Office Visit' }
      text_messaging_allowed { false }
      phone_number { '(111) 111-1111' }
      purpose_of_visit { 'Routine Follow-up' }
      provider_id { '0' }
      second_request { false }
      second_request_submitted { false }
      requested_phone_call { false }
      type_of_care_id { '323' }
      has_veteran_new_message { false }
      has_provider_new_message { true }
      provider_seen_appointment_request { false }
      best_timeto_call { ['Morning'] }
      appointment_request_detail_code { }

      facility do
        {
          name: 'DAYTSHR -Lima VA Clinic',
          facility_code: '984GB',
          state: 'OH',
          city: 'Lima',
          parent_site_code: '984'
        }
      end

      patient do
        {
          inpatient: false,
          text_messaging_allowed: false
        }
      end
    end

    trait :cancelation do
      appointment_request_detail_code { ['DETCODE8'] }
      status { 'Cancelled' }
    end
  end
end
