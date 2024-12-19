# frozen_string_literal: true

FactoryBot.define do
  factory :power_of_attorney_request, class: 'AccreditedRepresentativePortal::PowerOfAttorneyRequest' do
    association :claimant, factory: :user_account
    id { Faker::Internet.uuid }
    created_at { Time.current }

    trait :with_resolution do
      resolution { create(:power_of_attorney_request_resolution, :with_decision) }
    end
  end
end
