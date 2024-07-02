# frozen_string_literal: true

FactoryBot.define do
  factory :veteran_onboarding do
    display_onboarding_flow { false }
    user_account
  end
end
