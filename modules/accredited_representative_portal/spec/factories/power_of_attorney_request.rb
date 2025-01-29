# frozen_string_literal: true

FactoryBot.define do
  factory :power_of_attorney_request, class: 'AccreditedRepresentativePortal::PowerOfAttorneyRequest' do
    association :claimant, factory: :user_account
    association :power_of_attorney_form, strategy: :build

    association :power_of_attorney_holder, factory: %i[accredited_organization with_representatives], strategy: :create

    before(:create) do |poa_request|
      begin
        poa_request.accredited_individual_id = AccreditedIndividual.first&.id || create(:accredited_individual).id
      rescue ActiveModel::UnknownAttributeError
        Rails.logger.warn("accredited_individual_id column is missing")
      end
    end

    transient do
      resolution_created_at { nil }
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

    trait :with_declination do
      after(:build) do |poa_request, evaluator|
        poa_request.resolution = build(
          :power_of_attorney_request_resolution,
          :declination,
          power_of_attorney_request: poa_request,
          resolution_created_at: evaluator.resolution_created_at
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

    trait :with_veteran_claimant do
      association :power_of_attorney_form, :with_veteran_claimant, strategy: :build
    end

    trait :with_dependent_claimant do
      association :power_of_attorney_form, :with_dependent_claimant, strategy: :build
    end
  end
end
