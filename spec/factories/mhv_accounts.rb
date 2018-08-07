# frozen_string_literal: true

FactoryBot.define do
  factory :mhv_account do
    user_uuid { SecureRandom.uuid }
    account_state 'unknown'
    mhv_correlation_id nil
    registered_at nil
    upgraded_at nil
  end

  trait :upgraded do
    account_state :upgraded
    registered_at Time.current
    upgraded_at Time.current
  end

  trait :registered do
    account_state :registered
    registered_at Time.current
  end
end
