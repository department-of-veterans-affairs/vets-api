# frozen_string_literal: true

FactoryBot.define do
  factory :accredited_individual do
    transient do
      org_count { 1 }
    end

    ogc_id { SecureRandom.uuid }
    registration_number { Faker::Alphanumeric.alphanumeric(number: 5, min_numeric: 5) }
    individual_type { 'representative' }
    first_name { Faker::Name.first_name }
    last_name { Faker::Name.last_name }
    full_name { "#{first_name} #{last_name}" }

    trait :with_organizations do
      after(:create) do |individual, evaluator|
        individual.accredited_organizations << create_list(:accredited_organization, evaluator.org_count)

        individual.reload
      end
    end

    trait :representative do
      individual_type { 'representative' }
    end

    trait :attorney do
      poa_code { Faker::Alphanumeric.alphanumeric(number: 3).upcase }
      individual_type { 'attorney' }
    end

    trait :claims_agent do
      poa_code { Faker::Alphanumeric.alphanumeric(number: 3).upcase }
      individual_type { 'claims_agent' }
    end

    trait :with_location do
      location { 'POINT(-73.77623285 42.65140884)' }
    end

    trait :for_2122_2122a_pdf_fixture do
      id { 'bd22d501-b3df-4a52-9229-5c25b4d2036a' }
      first_name { 'John' }
      middle_initial { 'M' }
      last_name { 'Representative' }
      address_line1 { '123 Fake Representative St' }
      city { 'Portland' }
      state_code { 'OR' }
      zip_code { '12345' }
      country_code_iso3 { 'USA' }
      phone { '555-555-5555' }
      email { 'representative@example.com' }
      individual_type { 'attorney' }
    end
  end
end
