# frozen_string_literal: true

FactoryBot.define do
  factory :power_of_attorney_request_decision,
          class: 'AccreditedRepresentativePortal::PowerOfAttorneyRequestDecision' do
    association :creator, factory: :user_account
    association :resolution, factory: :power_of_attorney_request_resolution

    trait :acceptance do
      type { AccreditedRepresentativePortal::PowerOfAttorneyRequestDecision::Types::ACCEPTANCE }
    end

    trait :declination do
      type { AccreditedRepresentativePortal::PowerOfAttorneyRequestDecision::Types::DECLINATION }
    end
  end
end
