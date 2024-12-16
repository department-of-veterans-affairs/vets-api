# frozen_string_literal: true

FactoryBot.define do
  factory :power_of_attorney_request_resolution,
          class: 'AccreditedRepresentativePortal::PowerOfAttorneyRequestResolution' do
    association :power_of_attorney_request, factory: :power_of_attorney_request
    resolving_id { SecureRandom.uuid }
    reason_ciphertext { 'Encrypted Reason' }
    created_at { Time.current }
    encrypted_kms_key { SecureRandom.hex(16) }

    trait :with_expiration do
      resolving_type { 'AccreditedRepresentativePortal::PowerOfAttorneyRequestExpiration' }
      resolving { create(:power_of_attorney_request_expiration) }
    end

    trait :with_decision do
      resolving_type { 'AccreditedRepresentativePortal::PowerOfAttorneyRequestDecision' }
      resolving { create(:power_of_attorney_request_decision) }
    end
  end
end
