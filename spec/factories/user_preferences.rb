# frozen_string_literal: true

FactoryBot.define do
  factory :user_preference do
    account
    preference
    preference_choice
  end
end
