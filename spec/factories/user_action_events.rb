# frozen_string_literal: true

FactoryBot.define do
  factory :user_action_event do
    details { Faker::Lorem.sentence }
    event_id { 'test_event' }
    event_type { 1 }
  end
end
