# frozen_string_literal: true

FactoryBot.define do
  factory :appointment_form_v2, class: 'VAOS::V2::AppointmentForm' do
    transient do
      user { build(:user, :vaos) }
    end

    initialize_with { new(user, attributes) }

    trait :eligible do
      kind { 'cc' }
      status { 'proposed' }
      location_id { '983' }
      reason { 'Testing' }

      contact do
        {
          'telecom' => [
            {
              'type': 'phone',
              'value': '2125688889'
            },
            {
              'type': 'email',
              'value': 'judymorisooooooooooooon@gmail.com'
            }
          ]
        }
      end

      service_type { 'CCPOD' }
      requested_periods do
        [
          {
            'start' => DateTime.new(2021, 0o6, 15, 12, 0o0, 0).iso8601(3),
            'end' => DateTime.new(2021, 0o6, 15, 23, 59, 0).iso8601(3)
          }
        ]
      end
    end
  end
end
