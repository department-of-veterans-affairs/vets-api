# frozen_string_literal: true

FactoryBot.define do
  factory :pilot_representative, class: 'AccreditedRepresentativePortal::PilotRepresentative' do
    ogc_registration_number { Faker::Number.unique.number(digits: 6).to_s }
    email { Faker::Internet.unique.email }
  end
end
