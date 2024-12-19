# frozen_string_literal: true

FactoryBot.define do
  factory :excel_file_event do
    sequence(:filename) { |n| "22-10282_#{Time.zone.now.strftime('%Y%m%d')}_#{n}.csv" }
    retry_attempt { 0 }

    trait :successful do
      successful_at { Time.zone.now }
    end
  end
end
