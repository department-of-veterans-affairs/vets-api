# frozen_string_literal: true

FactoryBot.define do
  factory :preferred_facility do
    facility_code { '983' }
    account

    after(:build) do |preferred_facility|
      binding.pry; fail
    end
  end
end
