# frozen_string_literal: true

FactoryBot.define do
  factory :user_action do
    association :subject_user_verification, factory: :user_verification
    association :user_action_event
    status { 'initial' }
    acting_ip_address { Faker::Internet.ip_v4_address }
    acting_user_agent { Faker::Internet.user_agent }
    association :acting_user_verification, factory: :user_verification
  end
end
