# frozen_string_literal: true

FactoryBot.define do
  factory :preferred_facility do
    facility_code { '983' }
    user { create(:user, :loa3) }

    after(:build) do |preferred_facility|
    end
  end
end
