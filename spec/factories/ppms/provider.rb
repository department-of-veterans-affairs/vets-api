# frozen_string_literal: true

FactoryBot.define do
  factory :ppms_provider, class: 'PPMS::Provider' do
    provider_identifier { Faker::Number.number(digits: 6) }
    provider_name { Faker::Name.name }
    care_site { Faker::Company.name }
    gender { Faker::Gender.binary_type }

    trait :from_provider_locator do
      address_street { Faker::Address.street_address }
      address_city { Faker::Address.city }
      address_state_province { Faker::Address.state_abbr }
      address_postal_code { Faker::Address.zip }
      caresite_phone { Faker::PhoneNumber.phone_number }
      acc_new_patients { Faker::Boolean.boolean }
      latitude { Faker::Address.latitude }
      longitude { Faker::Address.longitude }
    end

    trait :from_provider_info do
      email { Faker::Internet.email }
      main_phone { Faker::PhoneNumber.phone_number }
      fax { Faker::PhoneNumber.phone_number }
      contact_method { 'phone' }

      sequence(:provider_type, %w[GroupPracticeOrAgency Individual].cycle)
    end

    trait :from_pos_locator do
      from_provider_locator
      from_provider_info
    end
  end
end
