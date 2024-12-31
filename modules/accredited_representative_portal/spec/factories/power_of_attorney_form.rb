# frozen_string_literal: true

form_data = <<~JSON
  {
    "authorizations": {
      "record_disclosure": true,
      "record_disclosure_limitations": [],
      "address_change": true
    },
    "dependent": {
      "name": {
        "first": "John",
        "middle": "Middle",
        "last": "Doe"
      },
      "address": {
        "address_line1": "123 Main St",
        "address_line2": "Apt 1",
        "city": "Springfield",
        "state_code": "IL",
        "country": "US",
        "zip_code": "62704",
        "zip_code_suffix": "6789"
      },
      "date_of_birth": "1980-12-31",
      "relationship": "Spouse",
      "phone": "1234567890",
      "email": "veteran@example.com"
    },
    "veteran": {
      "name": {
        "first": "John",
        "middle": "Middle",
        "last": "Doe"
      },
      "address": {
        "address_line1": "123 Main St",
        "address_line2": "Apt 1",
        "city": "Springfield",
        "state_code": "IL",
        "country": "US",
        "zip_code": "62704",
        "zip_code_suffix": "6789"
      },
      "ssn": "123456789",
      "va_file_number": "123456789",
      "date_of_birth": "1980-12-31",
      "service_number": "123456789",
      "service_branch": "ARMY",
      "phone": "1234567890",
      "email": "veteran@example.com"
    }
  }
JSON

FactoryBot.define do
  factory :power_of_attorney_form, class: 'AccreditedRepresentativePortal::PowerOfAttorneyForm' do
    data { form_data }

    factory :dynamic_power_of_attorney_form do
      data do
        {
          authorizations: {
            record_disclosure: Faker::Boolean.boolean,
            record_disclosure_limitations: %w[
              ALCOHOLISM
              DRUG_ABUSE
              HIV
              SICKLE_CELL
            ].select { rand < 0.5 },
            address_change: Faker::Boolean.boolean
          },
          dependent: nil,
          veteran: {
            name: {
              first: Faker::Name.first_name,
              middle: nil,
              last: Faker::Name.first_name
            },
            address: {
              address_line1: Faker::Address.street_address,
              address_line2: nil,
              city: Faker::Address.city,
              state_code: Faker::Address.state_abbr,
              country: 'US',
              zip_code: Faker::Address.zip_code,
              zip_code_suffix: nil
            },
            ssn: Faker::Number.number(digits: 9).to_s,
            va_file_number: Faker::Number.number(digits: 9).to_s,
            date_of_birth: Faker::Date.birthday(min_age: 21, max_age: 100).to_s,
            service_number: Faker::Number.number(digits: 9).to_s,
            service_branch: %w[
              ARMY
              NAVY
              AIR_FORCE
              MARINE_CORPS
              COAST_GUARD
              SPACE_FORCE
              NOAA
              USPHS
            ].sample,
            phone: Faker::PhoneNumber.phone_number,
            email: Faker::Internet.email
          }
        }.to_json
      end
    end
  end
end
