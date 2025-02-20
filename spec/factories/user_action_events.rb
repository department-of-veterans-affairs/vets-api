# frozen_string_literal: true

FactoryBot.define do
  factory :user_action_event do
    details { Faker::Lorem.sentence }
  end
end
