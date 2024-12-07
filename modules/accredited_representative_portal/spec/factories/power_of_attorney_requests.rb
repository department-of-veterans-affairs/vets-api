# frozen_string_literal: true

FactoryBot.define do
  factory :ar_power_of_attorney_request, class: 'AccreditedRepresentativePortal::PowerOfAttorneyRequest' do
    trait :with_form do
      after(:create) do |request|
        create(:ar_power_of_attorney_form, power_of_attorney_request: request)
      end
    end
  end
end
