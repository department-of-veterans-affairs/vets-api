# frozen_string_literal: true
FactoryBot.define do
  factory :address, class: Preneeds::Address do
    sequence(:street) { generate(:street) }
    sequence(:street2) { generate(:street2) }
    city 'NY'
    state 'NY'
    country 'USA'
    postal_code '10000'
  end
end
