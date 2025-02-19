# frozen_string_literal: true

FactoryBot.define do
  factory :user_action_event do
    details { Faker::Lorem.sentence }
    event_id { "event_#{SecureRandom.hex(4)}" }
    event_type { :authentication }
  end
end
