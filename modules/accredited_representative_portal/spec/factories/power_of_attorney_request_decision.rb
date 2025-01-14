# frozen_string_literal: true

FactoryBot.define do
  factory :power_of_attorney_request_decision,
          class: 'AccreditedRepresentativePortal::PowerOfAttorneyRequestDecision' do
    association :creator, factory: :user_account
    association :resolution, factory: :power_of_attorney_request_resolution

    transient do
      skip_creator { false }
      skip_resolution { false }
    end

    after(:build) do |decision, evaluator|
      decision.creator ||= build(:user_account) unless evaluator.skip_creator || decision.creator.present?

      unless evaluator.skip_resolution || decision.resolution.present?
        decision.resolution ||= build(:power_of_attorney_request_resolution, skip_poa_request: true)
      end
    end

    trait :acceptance do
      type { AccreditedRepresentativePortal::PowerOfAttorneyRequestDecision::Types::ACCEPTANCE }
    end

    trait :declination do
      type { AccreditedRepresentativePortal::PowerOfAttorneyRequestDecision::Types::DECLINATION }
    end
  end
end
