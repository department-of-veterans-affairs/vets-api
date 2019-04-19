# frozen_string_literal: true

FactoryBot.define do
  factory :preference_choice do
    sequence(:code) { |n| "choice_#{n}" }
    sequence(:description) { |n| "Description of Choice #{n}" }
    preference
  end
end
