# frozen_string_literal: true

FactoryBot.define do
  factory :user_action do
    acting_ip_address { Faker::Internet.ip_v4_address }
    acting_user_agent { Faker::Internet.user_agent }
    status { 'initial' }
    association :acting_user_account, factory: :user_account
    association :subject_user_account, factory: :user_account
    association :user_action_event

    trait :with_verification do
      association :subject_user_verification, factory: :user_verification
    end

    trait :success_status do
      status { 'success' }
    end

    trait :error_status do
      status { 'error' }
    end
  end
end
