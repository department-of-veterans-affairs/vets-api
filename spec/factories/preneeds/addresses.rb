# frozen_string_literal: true
FactoryGirl.define do
  factory :address, class: Preneeds::Address do
    sequence(:address1) { |n| "1st address line #{n}" }
    sequence(:address2) { |n| "2nd address line #{n}" }
    sequence(:address3) { |n| "3rd address line #{n}" }
    city 'NY'
    state 'NY'
    country_code 'US'
    postal_zip '10000'
  end
end
