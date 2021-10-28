# frozen_string_literal: true

FactoryBot.define do
  factory :race, class: 'Preneeds::Race' do
    is_american_indian_or_alaskan_native { true }
    is_asian { false }
    is_black_or_african_american { false }
    is_spanish_hispanic_latino { false }
    not_spanish_hispanic_latino { true }
    is_native_hawaiian_or_other_pacific_islander { false }
    is_white { false }
  end
end
