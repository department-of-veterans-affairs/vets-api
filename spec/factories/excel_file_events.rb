# frozen_string_literal: true

FactoryBot.define do
  factory :excel_file_event do
    sequence(:filename) { |n| "#{Time.zone.now.strftime('%Y%m%d')}_#{n}_vetsgov.xlsx" }
    retry_attempt { 0 }

    trait :successful do
      successful_at { Time.zone.now }
    end
  end
end
