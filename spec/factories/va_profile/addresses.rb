# frozen_string_literal: true

FactoryBot.define do
  factory :va_profile_address, class: 'VAProfile::Models::Address' do
    address_line1 { '140 Rock Creek Rd' }
    address_pou { VAProfile::Models::Address::RESIDENCE }
    address_type { VAProfile::Models::Address::DOMESTIC }
    bad_address { true }
    city { 'Washington' }
    country_name { 'USA' }
    country_code_iso3 { 'USA' }
    geocode_date { '2018-04-13T17:01:18Z' }
    geocode_precision { '100' }
    latitude { '38.901' }
    longitude { '-77.0347' }
    state_code { 'DC' }
    zip_code { '20011' }
    sequence(:transaction_id, 100) { |n| "c2fab2b5-6af0-45e1-a9e2-394347af9#{n}" }
    source_date          { '2018-04-09T11:52:03-06:00' }
    created_at           { '2017-04-09T11:52:03-06:00' }
    updated_at           { '2017-04-09T11:52:03-06:00' }
    vet360_id { '12345' }

    trait :mailing do
      address_pou { VAProfile::Models::Address::CORRESPONDENCE }
      address_line1 { '1515 Broadway' }
    end

    trait :domestic do
      address_type { VAProfile::Models::Address::DOMESTIC }
    end

    trait :international do
      address_type { VAProfile::Models::Address::INTERNATIONAL }
      international_postal_code { '100-0001' }
      state_code { nil }
      zip_code { nil }
    end

    trait :military_overseas do
      address_type { VAProfile::Models::Address::MILITARY }
    end

    trait :multiple_matches do
      address_line1 { '37 1st st' }
      city { 'Brooklyn' }
      state_code { 'NY' }
      zip_code { '11249' }
    end

    trait :override do
      address_pou { VAProfile::Models::Address::CORRESPONDENCE }
      id { 108_347 }
      address_line1 { '1494 Martin Luther King Rd' }
      address_line2 { 'c/o foo' }
      city { 'Fulton' }
      state_code { 'MS' }
      zip_code { '38843' }
      validation_key { 713_117_306 }
      vet360_id { '1' }
      source_system_user { '1234' }
      source_date { Time.now.utc.iso8601 }
      effective_start_date { Time.now.utc.iso8601 }
    end

    trait :id_error do
      address_pou { 'RESIDENCE' }
    end

    trait :contact_info_v2 do
      address_pou { 'RESIDENCE' }
    end

    trait :v2_override do
      id { 15_035 }
      address_pou { 'CORRESPONDENCE' }
      address_line1 { '1494 Martin Luther King Rd' }
      address_line2 { 'c/o foo' }
      city { 'Fulton' }
      state_code { 'MS' }
      zip_code { '38843' }
      validation_key { 713_117_306 }
      vet360_id { '1' }
      source_system_user { '1234' }
      source_date { '2024-08-27T18:51:06.012Z' }
      effective_start_date { '2024-08-27T18:51:06.012Z' }
    end
  end
end
