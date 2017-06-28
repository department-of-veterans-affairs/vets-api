# frozen_string_literal: true
FactoryGirl.define do
  factory :name_input, class: Preneeds::NameInput do
    sequence(:last_name) { |n| "last_name#{n}" }
    sequence(:first_name) { |n| "first_name#{n}" }
  end
end
