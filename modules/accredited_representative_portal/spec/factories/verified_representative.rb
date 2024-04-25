# frozen_string_literal: true

FactoryBot.define do
  factory :verified_representative, class: 'AccreditedRepresentativePortal::VerifiedRepresentative' do
    ogc_registration_number { Faker::Number.unique.number(digits: 6).to_s }
    first_name { Faker::Name.first_name }
    last_name { Faker::Name.last_name }
    middle_initial { Faker::Name.middle_name }
    email { Faker::Internet.unique.email }
  end
end
