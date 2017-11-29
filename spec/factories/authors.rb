# frozen_string_literal: true
FactoryBot.define do
  factory :author, class: 'Author' do
    sequence(:id)         { |n| n }
    sequence(:first_name) { %w(Al Zoe).sample }
    sequence(:last_name)  { |n| Faker::Name.last_name + n.to_s }
    sequence(:birthdate)  { (25..60).to_a.sample.years.ago }
    zipcode               { Faker::Address.zip }
  end
end
