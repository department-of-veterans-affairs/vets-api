# frozen_string_literal: true

FactoryBot.define do
  factory :representative, class: 'Veteran::Service::Representative' do
    representative_id { '1234' }
    poa_codes { ['A1Q'] }
    first_name { 'Bob' }
    last_name { 'Law' }
    phone_number { '1234567890' }
    phone { '222-222-2222' }
    email { 'example@email.com' }
    user_types { ['attorney'] }

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
    end
  end
end
