# frozen_string_literal: true

FactoryBot.define do
  factory :email, class: 'VAProfile::Models::Email' do
    sequence(:email_address, 100) { |n| "person#{n}@example.com" }
    sequence(:transaction_id, 100) { |n| "b2fab2b5-6af0-45e1-a9e2-394347af9#{n}" }
    source_date          { '2018-04-09T11:52:03-06:00' }
    created_at           { '2017-04-09T11:52:03-06:00' }
    updated_at           { '2017-04-09T11:52:03-06:00' }
    vet360_id { '12345' }

    trait :contact_info_v2 do
      source_date { '2024-08-27T18:51:06.000Z' }
      effective_start_date { '2024-08-27T18:51:06.000Z' }
    end
  end
end
