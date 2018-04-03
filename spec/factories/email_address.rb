# frozen_string_literal: true

FactoryBot.define do
  factory :email_address, class: 'EVSS::PCIU::EmailAddress' do
    sequence(:email, 100) { |n| "person#{n}@example.com" }
  end
end
