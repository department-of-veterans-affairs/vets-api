# frozen_string_literal: true

FactoryBot.define do
  factory :vye_address_change, class: 'Vye::AddressChange' do
    veteran_name { Faker::Name.name }
    address1 { Faker::Address.street_address }
    city { Faker::Address.city }
    state { Faker::Address.state_abbr }
    zip_code { Faker::Address.zip_code }
    origin { Vye::AddressChange.origins['frontend'] }
  end

  factory :vye_address_backend, class: 'Vye::AddressChange' do
    veteran_name { Faker::Name.name }
    address1 { Faker::Address.street_address }
    city { Faker::Address.city }
    state { Faker::Address.state_abbr }
    zip_code { Faker::Address.zip_code }
    origin { Vye::AddressChange.origins['backend'] }
  end
end
