# frozen_string_literal: true

FactoryBot.define do
  factory :preference do
    sequence(:code) { |n| "preference_#{n}" }
    sequence(:title) { |n| "Title of Preference #{n}" }

    trait :with_choices do
      after :create do |preference|
        create_list :preference_choice, 3, preference: preference
      end
    end
  end
end
