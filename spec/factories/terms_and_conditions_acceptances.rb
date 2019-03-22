# frozen_string_literal: true

FactoryBot.define do
  factory :terms_and_conditions_acceptance do
    association :terms_and_conditions
    user_uuid { SecureRandom.uuid }
    after(:build) do |terms_and_conditions_acceptance|
      terms_and_conditions_acceptance.mhv_account = build(:mhv_account, user_uuid: terms_and_conditions_acceptance.user_uuid)
    end
  end
end
