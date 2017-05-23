# frozen_string_literal: true
FactoryGirl.define do
  factory :mhv_account do
    user_uuid { SecureRandom.uuid }
    account_state 'unknown'
    registered_at nil
    upgraded_at nil
  end
end
