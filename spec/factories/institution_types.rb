# frozen_string_literal: true
FactoryGirl.define do
  factory :institution_type do
    sequence(:name) { |n| "Institution Type #{n}" }
  end
end
