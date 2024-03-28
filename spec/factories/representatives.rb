# frozen_string_literal: true

FactoryBot.define do
  factory :representative, class: 'Veteran::Service::Representative' do
    representative_id { '1234' }
    poa_codes { ['A1Q'] }
    first_name { Faker::Name.first_name }
    last_name { Faker::Name.last_name }
    ssn { Faker::Number.leading_zero_number(digits: 9).to_s }
    dob { '1987-10-17' }
  end
end
