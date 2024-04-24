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
        create_list(:accredited_individual, evaluator.rep_count, accredited_organizations: [organization])

        organization.reload
      end
    end
  end
end
