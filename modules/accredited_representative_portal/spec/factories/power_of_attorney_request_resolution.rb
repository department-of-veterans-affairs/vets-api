# frozen_string_literal: true

FactoryBot.define do
  factory :power_of_attorney_request_resolution,
          class: 'AccreditedRepresentativePortal::PowerOfAttorneyRequestResolution' do
    power_of_attorney_request

    trait :acceptance do
      resolving { create(:power_of_attorney_request_decision, :acceptance) }
    end

    trait :declination do
      resolving { create(:power_of_attorney_request_decision, :declination) }
      reason { "Didn't authorize treatment record disclosure" }
    end

    trait :expiration do
      resolving { create(:power_of_attorney_request_expiration) }
    end
  end
end
