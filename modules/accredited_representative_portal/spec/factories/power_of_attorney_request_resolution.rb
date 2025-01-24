# frozen_string_literal: true

FactoryBot.define do
  factory :power_of_attorney_request_resolution,
          class: 'AccreditedRepresentativePortal::PowerOfAttorneyRequestResolution' do
    power_of_attorney_request

    transient do
      resolution_created_at { nil }
    end

    trait :with_veteran_claimant do
      association :power_of_attorney_request, :with_veteran_claimant
    end

    trait :with_dependent_claimant do
      association :power_of_attorney_request, :with_dependent_claimant
    end

    trait :acceptance do
      after(:build) do |resolution, evaluator|
        resolution.resolving =
          build(
            :power_of_attorney_request_decision, :acceptance,
            resolution:
          )
        resolution.created_at = evaluator.resolution_created_at if evaluator.resolution_created_at
      end
    end

    trait :declination do
      after(:build) do |resolution, evaluator|
        resolution.resolving =
          build(
            :power_of_attorney_request_decision, :declination,
            resolution:
          )
        resolution.created_at = evaluator.resolution_created_at if evaluator.resolution_created_at
      end

      reason { "Didn't authorize treatment record disclosure" }
    end

    trait :expiration do
      after(:build) do |resolution, evaluator|
        resolution.resolving =
          build(
            :power_of_attorney_request_expiration,
            resolution:
          )
        resolution.created_at = evaluator.resolution_created_at if evaluator.resolution_created_at
      end
    end
  end
end
