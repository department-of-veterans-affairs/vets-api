# frozen_string_literal: true
FactoryGirl.define do
  factory :full_name, class: Preneeds::FullName do
    sequence(:last) { |n| "last #{n}" }
    sequence(:first) { |n| "first #{n}" }
    sequence(:middle) { |n| "middle #{n}" }
    sequence(:maiden) { |n| "maiden #{n}" }

    suffix 'Jr.'
  end
end
