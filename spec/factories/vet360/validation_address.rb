# frozen_string_literal: true

FactoryBot.define do
  factory :vet360_validation_address, class: 'Vet360::Models::ValidationAddress' do
    address_pou { Vet360::Models::Address::RESIDENCE }
    address_type { Vet360::Models::Address::DOMESTIC }
    country_name { 'USA' }
    country_code_iso3 { 'USA' }

    trait :multiple_matches do
      address_line1 { '37 1st st' }
      city { 'Brooklyn' }
      state_code { 'NY' }
      zip_code { '11249' }
    end

    trait :override do
      address_pou { Vet360::Models::Address::CORRESPONDENCE }
      address_line1 { '1494 Martin Luther King Rd' }
      address_line2 { 'c/o foo' }
      city { 'Fulton' }
      state_code { 'MS' }
      zip_code { '38843' }
    end
  end
end
