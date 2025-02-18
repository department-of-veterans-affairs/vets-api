# frozen_string_literal: true

FactoryBot.define do
  factory :user_action_event do
    details { Faker::Lorem.sentence }
    event_id { "user_login_#{SecureRandom.hex(4)}" }
    event_type { 0 }

    trait :authentication do
      event_type { 0 }
      event_id { "auth_#{SecureRandom.hex(4)}" }
    end

    trait :profile do
      event_type { 1 }
      event_id { "profile_#{SecureRandom.hex(4)}" }
    end
  end
end
