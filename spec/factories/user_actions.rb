# frozen_string_literal: true

FactoryBot.define do
  factory :user_action do
    sequence(:acting_ip_address) { |n| "192.168.1.#{n}" }
    sequence(:acting_user_agent) { |n| "Mozilla/5.0 (Test Browser #{n})" }
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
