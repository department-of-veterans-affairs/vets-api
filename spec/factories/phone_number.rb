# frozen_string_literal: true

FactoryBot.define do
  factory :phone_number, class: 'EVSS::PCIU::PhoneNumber' do
    country_code '1'
    number '4445551212'
    extension '101'
    effective_date '2017-08-07T19:43:59.383Z'

    trait :nil_effective_date do
      effective_date nil
    end
  end
end
