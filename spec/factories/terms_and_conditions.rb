# frozen_string_literal: true
FactoryGirl.define do
  factory :terms_and_conditions do
    name { Faker::Lorem.word }
    title { Faker::Lorem.sentence }
    text { Faker::Lorem.paragraph }
    version { Faker::App.version }
  end
end
