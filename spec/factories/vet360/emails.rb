# frozen_string_literal: true

FactoryBot.define do
  factory :email, class: 'Vet360::Models::Email' do
    sequence(:id) { |n| n }
    sequence(:email_address, 100) { |n| "person#{n}@example.com" }
    sequence(:transaction_id, 100) { |n| "#{n}" }
    effective_start_date '2017-04-09T11:52:03-06:00'
    effective_end_date   nil
    source_date          '2018-04-09T11:52:03-06:00'
    created_at           '2017-04-09T11:52:03-06:00'
    updated_at           '2017-04-09T11:52:03-06:00'
  end
end
