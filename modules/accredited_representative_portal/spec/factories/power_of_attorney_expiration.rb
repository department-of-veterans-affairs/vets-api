# frozen_string_literal: true

FactoryBot.define do
  factory :power_of_attorney_request_expiration,
          class: 'AccreditedRepresentativePortal::PowerOfAttorneyRequestExpiration' do
    id { Faker::Internet.uuid }
  end
end
