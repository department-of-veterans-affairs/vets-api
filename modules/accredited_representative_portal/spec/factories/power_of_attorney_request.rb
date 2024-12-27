# frozen_string_literal: true

FactoryBot.define do
  factory :power_of_attorney_request, class: 'AccreditedRepresentativePortal::PowerOfAttorneyRequest' do
    association :claimant, factory: :user_account

    trait :with_acceptance do
      resolution { create(:power_of_attorney_request_resolution, :acceptance) }
    end

    trait :with_declination do
      resolution { create(:power_of_attorney_request_resolution, :declination) }
    end

    trait :with_expiration do
      resolution { create(:power_of_attorney_request_resolution, :expiration) }
    end
  end
end
