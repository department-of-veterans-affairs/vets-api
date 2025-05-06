# frozen_string_literal: true

require 'va_profile/models/v3/validation_address'

FactoryBot.define do
  factory :va_profile_v3_validation_address, class: 'VAProfile::Models::V3::ValidationAddress' do
    address_pou { VAProfile::Models::V3::Address::RESIDENCE }
    address_type { VAProfile::Models::V3::Address::DOMESTIC }
    country_name { 'USA' }
    country_code_iso3 { 'USA' }

    trait :multiple_matches do
      address_line1 { '37 1st st' }
      city { 'Brooklyn' }
      state_code { 'NY' }
      zip_code { '11249' }
    end

    trait :override do
      address_pou { VAProfile::Models::V3::Address::CORRESPONDENCE }
      address_line1 { '1494 Martin Luther King Rd' }
      address_line2 { 'c/o foo' }
      city { 'Fulton' }
      state_code { 'MS' }
      zip_code { '38843' }
    end
  end
end
