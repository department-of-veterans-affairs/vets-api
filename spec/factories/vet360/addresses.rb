# frozen_string_literal: true

FactoryBot.define do
  factory :vet360_address, class: 'Vet360::Models::Address' do
    address_line1 { '140 Rock Creek Rd' }
    address_pou { Vet360::Models::Address::RESIDENCE }
    address_type { Vet360::Models::Address::DOMESTIC }
    city { 'Washington' }
    country_name { 'USA' }
    country_code_iso3 { 'USA' }
    state_code { 'DC' }
    zip_code { '20011' }
    sequence(:transaction_id, 100) { |n| "c2fab2b5-6af0-45e1-a9e2-394347af9#{n}" }
    source_date          { '2018-04-09T11:52:03-06:00' }
    created_at           { '2017-04-09T11:52:03-06:00' }
    updated_at           { '2017-04-09T11:52:03-06:00' }
    vet360_id { '12345' }

    trait :mailing do
      address_pou { Vet360::Models::Address::CORRESPONDENCE }
      address_line1 { '1515 Broadway' }
    end

    trait :domestic do
      address_type { Vet360::Models::Address::DOMESTIC }
    end

    trait :international do
      address_type { Vet360::Models::Address::INTERNATIONAL }
      international_postal_code { '100-0001' }
      state_code { nil }
      zip_code { nil }
    end

    trait :military_overseas do
      address_type { Vet360::Models::Address::MILITARY }
    end

    trait :multiple_matches do
      address_line1 { '37 1st st' }
      city { 'Brooklyn' }
      state_code { 'NY' }
      zip_code { '11249' }
    end

    trait :override do
      address_pou { Vet360::Models::Address::CORRESPONDENCE }
      id { 108347 }
      address_line1 { '1494 Martin Luther King Rd' }
      address_line2 { 'c/o foo' }
      city { 'Fulton' }
      state_code { 'MS' }
      zip_code { '38843' }
      validation_key { 713117306 }
      vet360_id { '1' }
      source_system_user { '1234' }
      source_date { Time.now.utc.iso8601 }
    end
  end
end
