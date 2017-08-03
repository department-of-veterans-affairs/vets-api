# frozen_string_literal: true
FactoryGirl.define do
  factory :name, class: Preneeds::Name do
    sequence(:last_name) { |n| "last_name#{n}" }
    sequence(:first_name) { |n| "first_name#{n}" }
    sequence(:middle_name) { |n| "middle_name#{n}" }
    sequence(:maiden_name) { |n| "maiden_name#{n}" }

    suffix 'Jr.'
  end
end
