# frozen_string_literal: true
FactoryGirl.define do
  factory :discharge_type, class: Preneeds::DischargeType do
    sequence(:id) { |n| n }
    sequence(:description) { |n| "description #{n}" }
  end
end
