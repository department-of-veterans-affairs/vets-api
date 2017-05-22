# frozen_string_literal: true
FactoryGirl.define do
  factory :mhv_account do
    user_uuid { SecureRandom.uuid }
    account_state 'unknown'
    registered_at nil
    upgraded_at nil

    factory :mhv_account_with_user do
      after(:build) do |mhv_account|
        create(:user, uuid: mhv_account.user_uuid)
      end
    end
  end
end
