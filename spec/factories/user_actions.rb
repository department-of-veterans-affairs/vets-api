# frozen_string_literal: true

FactoryBot.define do
  factory :user_action do
    acting_user_verification_id { create(:user_verification).id }
    subject_user_verification_id { create(:user_verification).id }
    user_action_event
    status { :initial }
    acting_ip_address { Faker::Internet.ip_v4_address }
    acting_user_agent { Faker::Internet.user_agent }
  end
end
