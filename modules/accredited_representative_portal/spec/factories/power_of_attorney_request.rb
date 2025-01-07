# frozen_string_literal: true

FactoryBot.define do
  factory :power_of_attorney_request, class: 'AccreditedRepresentativePortal::PowerOfAttorneyRequest' do
    association :claimant, factory: :user_account
    association :power_of_attorney_form, strategy: :build

    association :power_of_attorney_holder, factory: %i[accredited_organization with_representatives], strategy: :create
    accredited_individual { power_of_attorney_holder.accredited_individuals.first }

    transient do
      skip_resolution { false }
    end

    after(:build) do |power_of_attorney_request, evaluator|
      unless evaluator.skip_resolution || power_of_attorney_request.resolution.present?
        power_of_attorney_request.resolution ||= build(
          :power_of_attorney_request_resolution,
          :acceptance,
          power_of_attorney_request: power_of_attorney_request
        )
      end
    end

    trait :with_acceptance do
      resolution do
        create(
          :power_of_attorney_request_resolution,
          :acceptance,
          power_of_attorney_request: instance
        )
      end
    end

    trait :with_veteran_type_form do
      power_of_attorney_form { FactoryBot.build(:veteran_type_form) }
    end

    trait :with_declination do
      resolution do
        create(
          :power_of_attorney_request_resolution,
          :declination,
          power_of_attorney_request: instance
        )
      end
    end

    trait :with_expiration do
      resolution do
        create(
          :power_of_attorney_request_resolution,
          :expiration,
          power_of_attorney_request: instance
        )
      end
    end
  end
end
