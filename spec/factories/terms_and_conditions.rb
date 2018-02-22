# frozen_string_literal: true

FactoryBot.define do
  factory :terms_and_conditions do
    name { Faker::Lorem.word }
    title { Faker::Lorem.sentence }
    header_content { Faker::Lorem.paragraph }
    terms_content { Faker::Lorem.paragraph }
    yes_content { Faker::Lorem.sentence }
    no_content { Faker::Lorem.sentence }
    footer_content { Faker::Lorem.paragraph }
    version { Faker::App.version }
  end
end
