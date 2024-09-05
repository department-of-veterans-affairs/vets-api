# frozen_string_literal: true

FactoryBot.define do
  factory :vye_direct_deposit_change, class: 'Vye::DirectDepositChange' do
    full_name { Faker::Name.name }
    phone { Faker::Number.number(digits: 10) }
    email { Faker::Internet.email }
    acct_no { Faker::Bank.account_number(digits: 10) }
    acct_type { Vye::DirectDepositChange.acct_types.keys.sample }
    routing_no { Faker::Bank.routing_number }
    bank_name { Faker::Bank.name }
    bank_phone { Faker::Number.number(digits: 10) }
  end
end
