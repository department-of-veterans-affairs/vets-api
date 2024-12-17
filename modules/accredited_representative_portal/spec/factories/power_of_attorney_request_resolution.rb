# frozen_string_literal: true

FactoryBot.define do
  factory :power_of_attorney_request_resolution,
          class: 'AccreditedRepresentativePortal::PowerOfAttorneyRequestResolution' do
    association :power_of_attorney_request
    resolving_type { 'AccreditedRepresentativePortal::PowerOfAttorneyRequestExpiration' }
    reason { 'Test reason for resolution' }
    created_at { Time.current }
    encrypted_kms_key { SecureRandom.hex(16) }

    after(:build) do |resolution|
      resolution.id ||= SecureRandom.random_number(1000)
    end

    trait :with_expiration do
      resolving_type { 'AccreditedRepresentativePortal::PowerOfAttorneyRequestExpiration' }
      resolving { create(:power_of_attorney_request_expiration) }
    end

    trait :with_decision do
      resolving_type { 'AccreditedRepresentativePortal::PowerOfAttorneyRequestDecision' }
      resolving { create(:power_of_attorney_request_decision, creator: create(:user_account)) }
    end

    trait :with_declination do
      resolving_type { 'AccreditedRepresentativePortal::PowerOfAttorneyRequestDecision' }
      reason { "Didn't authorize treatment record disclosure" }
      resolving { create(:power_of_attorney_request_decision, creator: create(:user_account)) }
    end
  end
end
