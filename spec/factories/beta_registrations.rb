# frozen_string_literal: true

FactoryBot.define do
  factory :beta_registration do
    user_uuid { SecureRandom.uuid }
    sequence(:feature, 10) { |n| "feature_#{n}" }
  end
end
