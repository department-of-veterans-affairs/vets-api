# frozen_string_literal: true

FactoryBot.define do
  factory :user_account, class: 'UserAccount' do
    icn { Faker::Alphanumeric.alphanumeric(number: 10) }
  end
end
