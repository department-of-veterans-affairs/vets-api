# frozen_string_literal: true

FactoryBot.define do
  factory :organization, class: 'Veteran::Service::Organization' do
    poa { Faker::Alphanumeric.alphanumeric(number: 3) }

    name { 'Org Name' }

    trait :with_address do
      address_line1 { '123 East Main St' }
      address_line2 { 'Suite 1' }
      address_line3 { 'Address Line 3' }
      address_type { 'DOMESTIC' }
      city { 'My City' }
      country_name { 'United States of America' }
      country_code_iso3 { 'USA' }
      province { 'A Province' }
      international_postal_code { '12345' }
      state_code { 'ZZ' }
      zip_code { '12345' }
      zip_suffix { '6789' }
      lat { '39' }
      long { '-75' }
      location { "POINT(#{long} #{lat})" }
    end
  end
end
