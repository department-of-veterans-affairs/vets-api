# frozen_string_literal: true

FactoryBot.define do
  factory :power_of_attorney_request_decision,
          class: 'AccreditedRepresentativePortal::PowerOfAttorneyRequestDecision' do
    association :creator, factory: :user_account

    # By default build a valid declination decision
    type               { AccreditedRepresentativePortal::PowerOfAttorneyRequestDecision::Types::DECLINATION }
    declination_reason { :NOT_ACCEPTING_CLIENTS }
    power_of_attorney_holder_type { AccreditedRepresentativePortal::PowerOfAttorneyHolder::Types::VETERAN_SERVICE_ORGANIZATION }
    power_of_attorney_holder_poa_code { Faker::Alphanumeric.alphanumeric(number: 3) }
    accredited_individual {
      create(:representative, representative_id: Faker::Number.unique.number(digits: 6))
    }

    trait :acceptance do
      type               { AccreditedRepresentativePortal::PowerOfAttorneyRequestDecision::Types::ACCEPTANCE }
      declination_reason { nil }
    end
  end
end
