# frozen_string_literal: true

FactoryBot.define do
  factory :appointment_form, class: 'VAOS::AppointmentForm' do
    transient do
      user { FactoryBot.build(:user, :vaos) }
    end

    initialize_with { new(user, attributes) }

    trait :ineligible do
      scheduling_request_type { 'NEXT_AVAILABLE_APPT' }
      type { 'REGULAR' }
      appointment_kind { 'TRADITIONAL' }
      scheduling_method { 'direct' }
      appt_type { 'P' }
      appointment_type { 'Primary Care' }
      purpose { '9' }
      lvl { '1' }
      ekg { '' }
      lab { '' }
      x_ray { '' }
      preferred_email { 'test@va.gov' }
      time_zone { 'America/Denver' }
      desired_date { DateTime.new(2020, 0o1, 31, 0o0, 0o0, 0).iso8601(3) }
      date_time { DateTime.new(2020, 0o1, 31, 21, 0o0, 0).iso8601(3) }
      duration { 30 }
      booking_notes { 'Follow-up/Routine: abdominal pain' }
      clinic do
        {
          'site_code' => '983',
          'clinic_id' => '308',
          'clinic_name' => 'CHY PC KILPATRICK',
          'clinic_friendly_location_name' => 'Green Team Clinic1',
          'institution_name' => 'CHYSHR-Cheyenne VA Medical Center',
          'institution_code' => '983'
        }
      end
    end

    trait :eligible do
      ineligible

      desired_date { DateTime.new(2020, 0o2, 0o7, 0o0, 0o0, 0).iso8601(3) }
      date_time { DateTime.new(2020, 0o2, 0o7, 21, 0o0, 0).iso8601(3) }
    end

    trait :invalid do
      ineligible

      desired_date { DateTime.new(2020, 0o2, 0o6, 0o0, 0o0, 0).iso8601(3) }
      date_time { DateTime.new(2020, 0o2, 0o6, 21, 0o0, 0).iso8601(3) }
      clinic do
        {
          site_code: 'Invalid',
          clinic_id: 'Invalid',
          clinic_name: 'Invalid',
          clinic_friendly_location_name: 'Invalid',
          institution_name: 'Invalid',
          institution_code: 'Invalid'
        }
      end
    end
  end
end
