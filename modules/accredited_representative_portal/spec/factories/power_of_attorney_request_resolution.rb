# frozen_string_literal: true

FactoryBot.define do
  factory :power_of_attorney_request_resolution,
          class: 'AccreditedRepresentativePortal::PowerOfAttorneyRequestResolution' do
    power_of_attorney_request

    transient do
      skip_poa_request { false }
    end

    after(:build) do |resolution, evaluator|
      unless evaluator.skip_poa_request
       resolution.power_of_attorney_request ||= build(:power_of_attorney_request, :with_acceptance, :with_static_power_of_attorney_form, skip_resolution: true)
      end
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
