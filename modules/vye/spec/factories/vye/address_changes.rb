# frozen_string_literal: true

FactoryBot.define do
  factory :vye_address_change, class: 'Vye::AddressChange' do
    association :user_info, factory: :vye_user_info
    veteran_name { Faker::Name.name[0, 15] }
    address1 { Faker::Address.street_address }
    city { Faker::Address.city }
    state { Faker::Address.state_abbr }
    zip_code { Faker::Number.number(digits: 5) }
    origin { Vye::AddressChange.origins['frontend'] }
  end

  factory :vye_address_backend, class: 'Vye::AddressChange' do
    association :user_info, factory: :vye_user_info
    veteran_name { Faker::Name.name }
    address1 { Faker::Address.street_address }
    city { Faker::Address.city }
    state { Faker::Address.state_abbr }
    zip_code { Faker::Address.zip_code }
    origin { Vye::AddressChange.origins['backend'] }
  end
end
