# frozen_string_literal: true

FactoryBot.define do
  factory :va_profile_v3_address, class: 'VAProfile::Models::V3::Address' do
    address_line1 { '140 Rock Creek Rd' }
    address_pou { VAProfile::Models::V3::Address::RESIDENCE }
    address_type { VAProfile::Models::V3::Address::DOMESTIC }
    bad_address { true }
    city { 'Washington' }
    country_name { 'USA' }
    country_code_iso3 { 'USA' }
    geocode_date { '2024-08-27T18:51:06.012Z' }
    geocode_precision { '100' }
    latitude { '38.901' }
    longitude { '-77.0347' }
    state_code { 'DC' }
    zip_code { '20011' }
    sequence(:transaction_id, 100) { |n| "c2fab2b5-6af0-45e1-a9e2-394347af9#{n}" }
    source_date          { '2024-08-27T18:51:06.012Z' }
    created_at           { '2024-08-27T18:51:06.012Z' }
    updated_at           { '2024-08-27T18:51:06.012Z' }
    vet360_id { '1781151' }

    trait :mailing do
      address_pou { VAProfile::Models::V3::Address::CORRESPONDENCE }
      address_line1 { '1515 Broadway' }
    end

    trait :domestic do
      address_type { VAProfile::Models::V3::Address::DOMESTIC }
    end

    trait :international do
      address_type { VAProfile::Models::V3::Address::INTERNATIONAL }
      international_postal_code { '100-0001' }
      state_code { nil }
      zip_code { nil }
    end

    trait :military_overseas do
      address_type { VAProfile::Models::V3::Address::MILITARY }
    end

    trait :multiple_matches do
      address_line1 { '37 1st st' }
      city { 'Brooklyn' }
      state_code { 'NY' }
      zip_code { '11249' }
    end

    trait :incorrect_address_pou do
      address_line1 { '37 1st st' }
      city { 'Brooklyn' }
      state_code { 'NY' }
      zip_code { '11249' }
      address_pou { 'RESIDENCE/CHOICE' }
    end

    trait :override do
      address_pou { VAProfile::Models::V3::Address::RESIDENCE }
      address_line1 { '1494 Martin Luther King Rd' }
      address_line2 { nil }
      city { 'Fulton' }
      state_code { 'MS' }
      zip_code { '38843' }
      override_validation_key { 713_117_306 }
      validation_key { 713_117_306 }
      vet360_id { '1781151' }
      source_system_user { '123498767V234859' }
      source_date { '2024-09-16T16:09:37.000Z' }
      effective_start_date { '2024-09-16T16:09:37.000Z' }
    end

    trait :mobile do
      address_pou { VAProfile::Models::V3::Address::RESIDENCE }
      address_line1 { '1493 Martin Luther King Rd' }
      city { 'Fulton' }
      country_name { 'USA' }
      state_code { 'MS' }
      zip_code { '38843' }
      effective_start_date { '2024-08-27T18:51:06.00Z' }
      source_system_user { '123498767V234859' }
      source_date { '2024-08-27T18:51:06.000Z' }
    end

    trait :id_error do
      address_pou { 'RESIDENCE' }
    end

    trait :v2_override do
      id { 15_035 }
      address_pou { 'CORRESPONDENCE' }
      address_line1 { '2122 W Taylor St' }
      address_line2 { 'c/o foo' }
      city { 'Fulton' }
      state_code { 'MS' }
      zip_code { '38843' }
      override_validation_key { 713_117_306 }
      vet360_id { '1' }
      source_system_user { 'VAPROFILE_TEST_PARTNER' }
      source_date { '2024-08-27T18:51:06.012Z' }
      effective_start_date { '2024-08-27T18:51:06.012Z' }
    end
  end
end
