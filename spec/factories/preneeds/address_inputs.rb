# frozen_string_literal: true
FactoryGirl.define do
  factory :address_input, class: Preneeds::AddressInput do
    sequence(:address1) { |n| "#{n} West 51st Street" }
    city 'NY'
    state 'NY'
    country_code 'US'
    postal_zip '10000'
  end
end
