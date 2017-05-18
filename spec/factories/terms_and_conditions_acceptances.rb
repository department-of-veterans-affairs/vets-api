# frozen_string_literal: true
FactoryGirl.define do
  factory :terms_and_conditions_acceptance do
    association :terms_and_conditions
    user_uuid { SecureRandom.uuid }
  end
end
