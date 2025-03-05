# frozen_string_literal: true

FactoryBot.define do
  factory :user_account_accredited_individual,
          class: 'AccreditedRepresentativePortal::UserAccountAccreditedIndividual' do
    transient do
      poa_code { 'x35' }
    end

    accredited_individual_registration_number { Faker::Number.unique.number(digits: 6) }
    power_of_attorney_holder_type { 'veteran_service_organization' }
    user_account_email { Faker::Internet.email }
    user_account_icn { Faker::Number.unique.number(digits: 10) }
  end
end
