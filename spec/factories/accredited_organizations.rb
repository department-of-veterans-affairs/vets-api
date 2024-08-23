# frozen_string_literal: true

FactoryBot.define do
  factory :accredited_organization do
    transient do
      rep_count { 1 }
    end

    ogc_id { SecureRandom.uuid }
    poa_code { Faker::Alphanumeric.alphanumeric(number: 3).upcase }
    name { Faker::Company.name }

    trait :with_representatives do
      after(:create) do |organization, evaluator|
        organization.accredited_individuals << create_list(:accredited_individual, evaluator.rep_count)

        organization.reload
      end
    end

    trait :with_location do
      location { 'POINT(-73.77623285 42.65140884)' }
    end
  end
end
