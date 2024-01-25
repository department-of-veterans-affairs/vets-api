# frozen_string_literal: true

FactoryBot.define do
  factory :vye_address_change, class: 'Vye::AddressChange' do
    rpo { Faker::Address.city_prefix }
    benefit_type { Faker::Lorem.word }
    veteran_name { Faker::Name.name  }
    address1 { Faker::Address.street_address }
    address2 { Faker::Address.secondary_address }
    address3 { Faker::Address.building_number }
    address4 { Faker::Address.community }
    city { Faker::Address.city }
    state { Faker::Address.state_abbr }
    zip_code { Faker::Address.zip_code }
  end
end
