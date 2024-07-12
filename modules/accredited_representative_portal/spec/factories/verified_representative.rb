# frozen_string_literal: true

FactoryBot.define do
  factory :verified_representative, class: 'AccreditedRepresentativePortal::VerifiedRepresentative' do
    ogc_registration_number { Faker::Number.unique.number(digits: 6).to_s }
    email { Faker::Internet.unique.email }
  end
end
