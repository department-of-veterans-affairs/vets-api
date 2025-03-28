# frozen_string_literal: true

FactoryBot.define do
  factory :tooltip do
    association :user_account
    sequence(:tooltip_name) { |n| "tooltip_#{n}" }
    last_signed_in { Time.zone.now }
    counter { 0 }
    hidden { false }

    trait :hidden_tooltip do
      hidden { true }
    end

    trait :high_counter_tooltip do
      counter { 3 }
      hidden { true }
    end

    trait :duplicate_name do
      tooltip_name { 'duplicate_name' }
    end
  end
end
