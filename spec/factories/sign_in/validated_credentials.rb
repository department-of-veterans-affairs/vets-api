# frozen_string_literal: true

FactoryBot.define do
  factory :validated_credential, class: 'SignIn::ValidatedCredential' do
    skip_create

    user_verification { create(:user_verification) }
    credential_email { Faker::Internet.email }
    client_config { create(:client_config) }
    user_attributes do
      { first_name: Faker::Name.first_name,
        last_name: Faker::Name.last_name,
        email: Faker::Internet.email,
        all_emails: [Faker::Internet.email] }
    end
    device_sso { false }
    web_sso_session_id { Faker::Internet.uuid }

    initialize_with do
      new(user_verification:,
          client_config:,
          credential_email:,
          user_attributes:,
          device_sso:,
          web_sso_session_id:)
    end
  end
end
