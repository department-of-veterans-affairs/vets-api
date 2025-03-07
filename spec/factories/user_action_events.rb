# frozen_string_literal: true

FactoryBot.define do
  factory :user_action_event do
    details { Faker::Lorem.sentence }
    event_type { Faker::Lorem.word }
    identifier { Faker::Lorem.unique.word }
  end
end
