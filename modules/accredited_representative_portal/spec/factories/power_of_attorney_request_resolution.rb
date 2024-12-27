# frozen_string_literal: true

FactoryBot.define do
  factory :power_of_attorney_request_resolution,
          class: 'AccreditedRepresentativePortal::PowerOfAttorneyRequestResolution' do
    power_of_attorney_request

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
      after(:create) do |resolution|
        resolution.power_of_attorney_request.accredited_individual.update(poa_code: "123")
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
