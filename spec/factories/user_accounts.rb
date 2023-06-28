# frozen_string_literal: true

FactoryBot.define do
  factory :user_account, class: 'UserAccount' do
    icn { Faker::Alphanumeric.alphanumeric(number: 10) }
  end
  factory :user_account_with_verification, class: 'UserAccount' do
    icn { Faker::Alphanumeric.alphanumeric(number: 10) }
    user_verifications { create_list(:dslogon_user_verification, 1) }
  end
end
