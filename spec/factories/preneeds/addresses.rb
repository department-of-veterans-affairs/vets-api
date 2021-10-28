# frozen_string_literal: true

FactoryBot.define do
  factory :address, class: 'Preneeds::Address' do
    sequence(:street) { generate(:street) }
    sequence(:street2) { generate(:street2) }
    city { 'NY' }
    state { 'NY' }
    country { 'USA' }
    postal_code { '10000' }
  end

  factory :foreign_address, class: 'Preneeds::Address' do
    sequence(:street) { generate(:street) }
    sequence(:street2) { generate(:street2) }
    city { 'somewhere' }
    country { 'AZE' }
    postal_code { '12323-98AF' }
  end
end
