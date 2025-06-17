# frozen_string_literal: true

FactoryBot.define do
  factory :power_of_attorney_request, class: 'AccreditedRepresentativePortal::PowerOfAttorneyRequest' do
    association :claimant, factory: :user_account
    association :power_of_attorney_form, strategy: :build

    transient do
      poa_code { Faker::Alphanumeric.alphanumeric(number: 3) }
      accredited_individual { nil }
      resolution_created_at { nil }
      accredited_organization { nil }
    end

    power_of_attorney_holder_type { 'veteran_service_organization' }

    after(:build) do |poa_request, evaluator|
      poa_request.accredited_organization = evaluator.accredited_organization ||
                                            create(:organization)

      if evaluator.accredited_individual
        poa_request.accredited_individual = evaluator.accredited_individual
      else
        accredited_individual =
          create(:representative,
                 representative_id: Faker::Number.unique.number(digits: 6),
                 poa_codes: [evaluator.poa_code])

        poa_request.accredited_individual = accredited_individual
      end

      poa_request.power_of_attorney_holder_poa_code = evaluator.poa_code if evaluator.poa_code.present?
    end

    trait :unresolved do
      # Default state, no resolution needed
    end

    trait :with_acceptance do
      after(:build) do |poa_request, evaluator|
        poa_request.resolution = build(
          :power_of_attorney_request_resolution,
          :acceptance,
          power_of_attorney_request: poa_request,
          resolution_created_at: evaluator.resolution_created_at
        )
      end
    end

    trait :with_form_submission do
      after(:build) do |poa_request, _evaluator|
        poa_request.power_of_attorney_form_submission = build(
          :power_of_attorney_form_submission,
          status: :succeeded,
          power_of_attorney_request: poa_request
        )
      end
    end

    trait :with_pending_form_submission do
      after(:build) do |poa_request, _evaluator|
        poa_request.power_of_attorney_form_submission = build(
          :power_of_attorney_form_submission,
          status: nil,
          power_of_attorney_request: poa_request
        )
      end
    end

    trait :with_failed_form_submission do
      after(:build) do |poa_request, _evaluator|
        poa_request.power_of_attorney_form_submission = build(
          :power_of_attorney_form_submission,
          power_of_attorney_request: poa_request,
          status: :failed
        )
      end
    end

    trait :with_declination do
      after(:build) do |poa_request, evaluator|
        decision = build(
          :power_of_attorney_request_decision,
          type: AccreditedRepresentativePortal::PowerOfAttorneyRequestDecision::Types::DECLINATION,
          declination_reason: :NOT_ACCEPTING_CLIENTS
        )

        poa_request.resolution = build(
          :power_of_attorney_request_resolution,
          power_of_attorney_request: poa_request,
          resolving: decision,
          created_at: evaluator.resolution_created_at
        )
      end
    end

    trait :with_expiration do
      after(:build) do |poa_request, evaluator|
        poa_request.resolution = build(
          :power_of_attorney_request_resolution,
          :expiration,
          power_of_attorney_request: poa_request,
          resolution_created_at: evaluator.resolution_created_at
        )
      end
    end

    trait :with_replacement do
      after(:build) do |poa_request, evaluator|
        poa_request.resolution = build(
          :power_of_attorney_request_resolution,
          :replacement,
          power_of_attorney_request: poa_request,
          resolution_created_at: evaluator.resolution_created_at
        )
      end
    end

    trait :with_veteran_claimant do
      association :power_of_attorney_form, :with_veteran_claimant, strategy: :build
    end

    trait :with_dependent_claimant do
      association :power_of_attorney_form, :with_dependent_claimant, strategy: :build
    end

    trait :fully_redacted do
      redacted_at { 1.hour.ago }

      after(:create) do |request, _evaluator|
        request.power_of_attorney_form&.delete
        request.reload
      end
    end
  end
end
