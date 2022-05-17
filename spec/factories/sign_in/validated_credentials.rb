# frozen_string_literal: true

FactoryBot.define do
  factory :validated_credential, class: 'SignIn::ValidatedCredential' do
    skip_create

    user_verification { create(:user_verification) }
    credential_email { Faker::Internet.email }

    initialize_with do
      new(user_verification: user_verification,
          credential_email: credential_email)
    end
  end
end
