# frozen_string_literal: true

FactoryBot.define do
  factory :validated_credential, class: 'SignIn::ValidatedCredential' do
    skip_create

    user_verification { create(:user_verification) }
    credential_email { Faker::Internet.email }
    client_id { create(:client_config).client_id }

    initialize_with do
      new(user_verification: user_verification,
          client_id: client_id,
          credential_email: credential_email)
    end
  end
end
