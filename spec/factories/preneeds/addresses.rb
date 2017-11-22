# frozen_string_literal: true
FactoryBot.define do
  factory :address, class: Preneeds::Address do
    sequence(:street) { |n| "street #{n}" }
    sequence(:street2) { |n| "street2 #{n}" }
    city 'NY'
    state 'NY'
    country 'USA'
    postal_code '10000'
  end
end
