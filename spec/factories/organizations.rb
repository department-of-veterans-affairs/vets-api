# frozen_string_literal: true

FactoryBot.define do
  factory :organization, class: 'Veteran::Service::Organization' do
    poa { Faker::Alphanumeric.alphanumeric(number: 3) }

    name { 'Org Name' }
  end
end
