# frozen_string_literal: true

FactoryBot.define do
  factory :appointment_form, class: 'VAOS::AppointmentForm' do
    transient do
      user { build(:user, :vaos) }
    end

    initialize_with { new(user, attributes) }

    trait :ineligible do
      scheduling_request_type { 'NEXT_AVAILABLE_APPT' }
      type { 'REGULAR' }
      appointment_kind { 'TRADITIONAL' }
      scheduling_method { 'direct' }
      appt_type { 'P' }
      purpose { '9' }
      lvl { '1' }
      ekg { '' }
      lab { '' }
      x_ray { '' }
      preferred_email { 'abraham.lincoln@va.gov' }
      time_zone { 'America/Denver' }
      desired_date { 5.days.from_now.utc.change(hour: 0).iso8601(3) }
      date_time { 5.days.from_now.utc.iso8601(3) }
      duration { 30 }
      booking_notes { 'Follow-up/Routine: abdominal pain' }
      clinic do
        {
          site_code: '983',
          clinic_id: '308',
          clinic_name: 'CHY PC KILPATRICK',
          clinic_friendly_location_name: 'Green Team Clinic1',
          institution_name: 'CHYSHR-Cheyenne VA Medical Center',
          institution_code: '983'
        }
      end
    end

    trait :eligible do
      # Still need to find one that's eligible for a successful test
    end
  end
end
