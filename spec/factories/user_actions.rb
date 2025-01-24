# frozen_string_literal: true

FactoryBot.define do
  factory :user_action do
    acting_ip_address { Faker::Internet.ip_v4_address }
    acting_user_agent { Faker::Internet.user_agent }
    status { 'initial' }
    association :acting_user_verification, factory: :user_verification
    association :subject_user_verification, factory: :user_verification
    association :user_action_event

    trait :system_initiated do
      acting_user_verification { nil }
      acting_ip_address { nil }
      acting_user_agent { nil }
    end

    trait :success_status do
      status { 'success' }
    end

    trait :error_status do
      status { 'error' }
    end
  end
end
