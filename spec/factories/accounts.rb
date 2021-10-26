# frozen_string_literal: true

FactoryBot.define do
  factory :account do
    uuid { SecureRandom.uuid }
    idme_uuid { SecureRandom.uuid }
    sec_id { Faker::Number.number(digits: 10) }
    logingov_uuid { SecureRandom.uuid }
    icn { Faker::Alphanumeric.alphanumeric(number: 10) }
    edipi { Faker::Number.number(digits: 10) }
  end
end
