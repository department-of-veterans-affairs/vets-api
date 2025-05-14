# frozen_string_literal: true

FactoryBot.define do
  factory :power_of_attorney_request_decision,
          class: 'AccreditedRepresentativePortal::PowerOfAttorneyRequestDecision' do
    association :creator, factory: :user_account

    # By default build a valid declination decision
    type               { AccreditedRepresentativePortal::PowerOfAttorneyRequestDecision::Types::DECLINATION }
    declination_reason { :NOT_ACCEPTING_CLIENTS }

    trait :acceptance do
      type               { AccreditedRepresentativePortal::PowerOfAttorneyRequestDecision::Types::ACCEPTANCE }
      declination_reason { nil }
    end
  end
end
