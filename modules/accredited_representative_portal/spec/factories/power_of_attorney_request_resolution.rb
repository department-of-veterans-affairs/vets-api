# frozen_string_literal: true

FactoryBot.define do
  factory :power_of_attorney_request_resolution,
          class: 'AccreditedRepresentativePortal::PowerOfAttorneyRequestResolution' do
    association :power_of_attorney_request
    resolving_type { 'AccreditedRepresentativePortal::PowerOfAttorneyRequestExpiration' }
    reason { 'Test reason for resolution' }
    created_at { Time.current }

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
