# frozen_string_literal: true

FactoryBot.define do
  factory :user_credential_email, class: 'UserCredentialEmail' do
    user_verification { create(:user_verification) }
    credential_email { Faker::Internet.email }
  end
end
