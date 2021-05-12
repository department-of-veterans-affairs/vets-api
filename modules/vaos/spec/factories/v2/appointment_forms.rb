# frozen_string_literal: true

FactoryBot.define do
  factory :appointment_form_v2, class: 'VAOS::V2::AppointmentForm' do
    transient do
      user { build(:user, :vaos) }
    end

    initialize_with { new(user, attributes) }

    trait :eligible do
      kind { 'clinic' }
      status { 'proposed' }
      location_id { '983' }
      clinic { '308' }
      reason { 'reason' }
      slot do
        {
          'id' => 'A1',
          'start' => DateTime.new(2020, 0o1, 31, 0o0, 0o0, 0).iso8601(3),
          'end' => DateTime.new(2020, 0o1, 31, 0o0, 0o0, 0).iso8601(3)
        }
      end
      contact do
        {
          'telecom' => [
            {
              'type' => 'email',
              'value' => 'person@example.com'
            },
            {
              'type' => 'phone',
              'value' => '2125551212'
            }
          ]
        }
      end

      service_type { 'primary care' }
      requested_periods do
        [
          {
            'start' => DateTime.new(2020, 0o1, 31, 0o0, 0o0, 0).iso8601(3),
            'end' => DateTime.new(2020, 0o1, 31, 21, 0o0, 0).iso8601(3)
          },
          {
            'start' => DateTime.new(2020, 0o3, 31, 0o0, 0o0, 0).iso8601(3),
            'end' => DateTime.new(2020, 0o3, 31, 21, 0o0, 0).iso8601(3)
          }
        ]
      end
    end
  end
end
