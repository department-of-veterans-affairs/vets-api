# frozen_string_literal: true

FactoryBot.define do
  factory :user_action_event do
    details { 'User logged in' }
    slug { 'user_login' }
    event_type { :authentication }
  end
end
