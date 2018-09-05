# frozen_string_literal: true

FactoryBot.define do
  factory :preference do
    sequence(:code) { |n| "preference_#{n}" }
    sequence(:title) { |n| "Title of Preference #{n}" }
  end
end
