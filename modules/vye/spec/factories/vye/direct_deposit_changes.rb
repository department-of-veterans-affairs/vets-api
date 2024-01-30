# frozen_string_literal: true

FactoryBot.define do
  factory :vye_direct_deposit_change, class: 'Vye::DirectDepositChange' do
    rpo { Faker::Lorem.word }
    ben_type { Faker::Lorem.word }
    full_name { Faker::Name.name }
    phone { Faker::PhoneNumber.phone_number }
    phone2 { Faker::PhoneNumber.phone_number }
    email { Faker::Internet.email }
    acct_no { Faker::Bank.account_number(digits: 10) }
    acct_type { 'checking' }
    routing_no { Faker::Bank.routing_number }
    chk_digit { Faker::Number.digit }
    bank_name { Faker::Bank.name }
    bank_phone { Faker::PhoneNumber.phone_number }
  end
end
