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
        email: Faker::Internet.email }
    end

    initialize_with do
      new(user_verification:,
          client_config:,
          credential_email:,
          user_attributes:)
    end
  end
end
