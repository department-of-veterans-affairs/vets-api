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

    trait :with_invalid_type do
      resolving_type { 'AccreditedRepresentativePortal::InvalidType' }
      resolving { AccreditedRepresentativePortal::InvalidType.new }
    end
  end
end

module AccreditedRepresentativePortal
  class InvalidType
    def method_missing(_method, *_args) = self

    def respond_to_missing?(_method, _include_private = false) = true

    def id = nil

    def self.method_missing(_method, *_args) = NullObject.new

    def self.respond_to_missing?(_method, _include_private = false) = true
  end

  class NullObject
    def method_missing(_method, *_args) = self

    def respond_to_missing?(*) = true

    def nil? = true

    def to_s = ''
  end
end
