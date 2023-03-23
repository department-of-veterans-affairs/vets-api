# frozen_string_literal: true

FactoryBot.define do
  factory :validated_credential, class: 'SignIn::ValidatedCredential' do
    skip_create

    user_verification { create(:user_verification) }
    credential_email { Faker::Internet.email }
    client_config { create(:client_config) }

    initialize_with do
      new(user_verification:,
          client_config:,
          credential_email:)
    end
  end
end
