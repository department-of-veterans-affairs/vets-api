# frozen_string_literal: true

FactoryBot.define do
  factory :race, class: Preneeds::Race do
    is_american_indian_or_alaskan_native { true }
    not_spanish_hispanic_latino { true }
  end
end
