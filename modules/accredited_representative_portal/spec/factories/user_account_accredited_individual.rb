# frozen_string_literal: true

FactoryBot.define do
  factory :user_account_accredited_individual,
          class: 'AccreditedRepresentativePortal::UserAccountAccreditedIndividual' do
    accredited_individual_registration_number { Faker.id }
    power_of_attorney_holder_type { 'veteran_service_organization' }
    user_account_email { Faker.email }
    user_account_icn { Faker.uuid }
  end
end
