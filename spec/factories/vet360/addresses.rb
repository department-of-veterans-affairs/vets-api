# frozen_string_literal: true

FactoryBot.define do
  factory :vet360_address, class: 'Vet360::Models::Address' do
    address_line_1 '123 Main Street'
    address_pou Vet360::Models::Address::RESIDENCE
    address_type Vet360::Models::Address::DOMESTIC
    city 'Denver'
    country 'USA'
    state_abbr 'CO'
    zip_code '80202'
    sequence(:id) { |n| n }
    sequence(:transaction_id, 100, &:to_s)
    source_date          '2018-04-09T11:52:03-06:00'
    created_at           '2017-04-09T11:52:03-06:00'
    updated_at           '2017-04-09T11:52:03-06:00'

    trait :mailing do
      address_pou Vet360::Models::Address::CORRESPONDENCE
      address_line_1 '1515 Broadway'
    end

    trait :international do
      address_type Vet360::Models::Address::INTERNATIONAL
    end

    trait :military_overseas do
      address_type Vet360::Models::Address::MILITARY
    end
  end
end
