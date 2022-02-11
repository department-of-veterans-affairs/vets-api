# frozen_string_literal: true

FactoryBot.define do
  factory :tud_account, class: 'TestUserDashboard::TudAccount' do
    account_uuid { '123456789' }
    first_name { Faker::Name.first_name }
    last_name { Faker::Name.last_name }
    email { Faker::Internet.email }
    gender { Faker::Gender.short_binary_type.upcase }
    id_types { ['idme'] }
  end
end
