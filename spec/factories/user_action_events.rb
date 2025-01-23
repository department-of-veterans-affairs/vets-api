# frozen_string_literal: true

FactoryBot.define do
  factory :user_action_event do
    sequence(:details) { |n| "User action event details #{n}" }
  end
end
