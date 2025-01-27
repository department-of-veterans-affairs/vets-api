# frozen_string_literal: true

FactoryBot.define do
  factory :power_of_attorney_request, class: 'AccreditedRepresentativePortal::PowerOfAttorneyRequest' do
    association :claimant, factory: :user_account
    association :power_of_attorney_form, strategy: :build

    association :power_of_attorney_holder, factory: %i[accredited_organization with_representatives], strategy: :create

    trait :with_acceptance do
      resolution { create(:power_of_attorney_request_resolution, :acceptance) }
    end

    trait :with_declination do
      resolution { create(:power_of_attorney_request_resolution, :declination) }
    end

    trait :with_expiration do
      resolution { create(:power_of_attorney_request_resolution, :expiration) }
    end

    trait :with_veteran_claimant do
      association :power_of_attorney_form, :with_veteran_claimant, strategy: :build
    end

    trait :with_dependent_claimant do
      association :power_of_attorney_form, :with_dependent_claimant, strategy: :build
    end
  end
end
