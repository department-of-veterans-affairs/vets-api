# frozen_string_literal: true

FactoryBot.define do
  factory :power_of_attorney_request_resolution,
          class: 'AccreditedRepresentativePortal::PowerOfAttorneyRequestResolution' do
    power_of_attorney_request

    trait :with_veteran_claimant do
      association :power_of_attorney_request, :with_veteran_claimant
    end

    trait :with_dependent_claimant do
      association :power_of_attorney_request, :with_dependent_claimant
    end

    trait :acceptance do
      after(:build) do |resolution|
        resolution.resolving =
          build(
            :power_of_attorney_request_decision, :acceptance,
            resolution:
          )
      end
    end

    trait :declination do
      after(:build) do |resolution|
        resolution.resolving =
          build(
            :power_of_attorney_request_decision, :declination,
            resolution:
          )
      end

      reason { "Didn't authorize treatment record disclosure" }
    end

    trait :expiration do
      after(:build) do |resolution|
        resolution.resolving =
          build(
            :power_of_attorney_request_expiration,
            resolution:
          )
      end
    end
  end
end
