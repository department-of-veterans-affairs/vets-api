# frozen_string_literal: true

FactoryBot.define do
  factory :provider, class: Provider do
    ProviderSpecialties { [] }

    trait :from_provider_locator do
      ProviderIdentifier { Faker::Number.number(digits: 6) }
      Name { Faker::Name.name }
      AddressStreet { Faker::Address.street_address }
      AddressCity { Faker::Address.city }
      AddressStateProvince { Faker::Address.state_abbr }
      AddressPostalCode { Faker::Address.zip }
      CareSitePhoneNumber { Faker::PhoneNumber.phone_number }
      IsAcceptingNewPatients { Faker::Boolean.boolean }
      ProviderGender { Faker::Gender.binary_type }
      Latitude { Faker::Address.latitude }
      Longitude { Faker::Address.longitude }
    end

    trait :from_provider_info do
      Email { Faker::Internet.email }
      MainPhone { Faker::PhoneNumber.phone_number }
      OrganizationFax { Faker::PhoneNumber.phone_number }
      ContactMethod { 'phone' }
    end

    trait :from_pos_locator do
      from_provider_locator
      from_provider_info
    end
  end
end
