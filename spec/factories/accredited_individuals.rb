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
  end
end
