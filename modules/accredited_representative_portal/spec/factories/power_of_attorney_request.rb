# frozen_string_literal: true

FactoryBot.define do
  factory :power_of_attorney_request, class: 'AccreditedRepresentativePortal::PowerOfAttorneyRequest' do
    association :claimant, factory: :user_account
    association :power_of_attorney_form, strategy: :build

    # Temporarily set a default value for power_of_attorney_holder_type
    power_of_attorney_holder_type { 'AccreditedOrganization' }
    # only set the id if the column exists
    power_of_attorney_holder_id { SecureRandom.uuid } if AccreditedRepresentativePortal::PowerOfAttorneyRequest.column_names.include?('power_of_attorney_holder_id')

    before(:create) do |poa_request|
      if poa_request.respond_to?(:accredited_individual_id)
        poa_request.accredited_individual_id = AccreditedIndividual.first&.id || create(:accredited_individual).id
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
