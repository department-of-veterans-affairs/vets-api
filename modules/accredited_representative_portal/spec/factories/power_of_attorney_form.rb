# frozen_string_literal: true

dependent_claimant_data_hash = {
  authorizations: {
    recordDisclosureLimitations: [],
    addressChange: true
  },
  dependent: {
    name: {
      first: 'John',
      middle: 'Middle',
      last: 'Doe'
    },
    address: {
      addressLine1: '123 Main St',
      addressLine2: 'Apt 1',
      city: 'Springfield',
      stateCode: 'IL',
      country: 'US',
      zipCode: '62704',
      zipCodeSuffix: '6789'
    },
    dateOfBirth: '1980-12-31',
    relationship: 'Spouse',
    phone: '1234567890',
    email: 'veteran@example.com'
  },
  veteran: {
    name: {
      first: 'John',
      middle: 'Middle',
      last: 'Doe'
    },
    address: {
      addressLine1: '123 Main St',
      addressLine2: 'Apt 1',
      city: 'Springfield',
      stateCode: 'IL',
      country: 'US',
      zipCode: '62704',
      zipCodeSuffix: '6789'
    },
    ssn: '123456789',
    vaFileNumber: '123456789',
    dateOfBirth: '1980-12-31',
    serviceNumber: '123456789',
    serviceBranch: 'ARMY',
    phone: '1234567890',
    email: 'veteran@example.com'
  }
}

veteran_claimant_data_hash = {
  authorizations: {
    recordDisclosureLimitations: %w[
      HIV
      DRUG_ABUSE
    ],
    addressChange: true
  },
  dependent: nil,
  veteran: {
    name: {
      first: 'John',
      middle: 'Middle',
      last: 'Doe'
    },
    address: {
      addressLine1: '123 Main St',
      addressLine2: 'Apt 1',
      city: 'Springfield',
      stateCode: 'IL',
      country: 'US',
      zipCode: '62704',
      zipCodeSuffix: '6789'
    },
    ssn: '123456789',
    vaFileNumber: '123456789',
    dateOfBirth: '1980-12-31',
    serviceNumber: '123456789',
    serviceBranch: 'ARMY',
    phone: '1234567890',
    email: 'veteran@example.com'
  }
}

FactoryBot.define do
  factory :power_of_attorney_form, class: 'AccreditedRepresentativePortal::PowerOfAttorneyForm' do
    data { data_hash.to_json }

    transient do
      data_hash do
        {
          authorizations: {
            recordDisclosureLimitations: %w[
              ALCOHOLISM
              DRUG_ABUSE
              HIV
              SICKLE_CELL
            ].select { rand < 0.5 },
            addressChange: Faker::Boolean.boolean
          },
          dependent: nil,
          veteran: {
            name: {
              first: Faker::Name.first_name,
              middle: nil,
              last: Faker::Name.first_name
            },
            address: {
              addressLine1: Faker::Address.street_address,
              addressLine2: nil,
              city: Faker::Address.city,
              stateCode: Faker::Address.state_abbr,
              country: 'US',
              zipCode: Faker::Address.zip_code,
              zipCodeSuffix: nil
            },
            ssn: Faker::Number.number(digits: 9).to_s,
            vaFileNumber: Faker::Number.number(digits: 9).to_s,
            dateOfBirth: Faker::Date.birthday(min_age: 21, max_age: 100).to_s,
            serviceNumber: Faker::Number.number(digits: 9).to_s,
            serviceBranch: %w[
              ARMY
              NAVY
              AIR_FORCE
              MARINE_CORPS
              COAST_GUARD
              SPACE_FORCE
              NOAA
              USPHS
            ].sample,
            phone: Faker::PhoneNumber.phone_number.gsub(/\D/, ''),
            email: Faker::Internet.email
          }
        }
      end
    end

    trait :with_veteran_claimant do
      transient do
        data_hash { veteran_claimant_data_hash }
      end
    end

    trait :with_dependent_claimant do
      transient do
        data_hash { dependent_claimant_data_hash }
      end
    end
  end
end
