# frozen_string_literal: true

FactoryBot.define do
  factory :code_container, class: 'SignIn::CodeContainer' do
    code_challenge { Base64.urlsafe_encode64(SecureRandom.hex) }
    code { SecureRandom.hex }
    client_id { create(:client_config).client_id }
    user_verification_id { create(:user_verification).id }
    user_attributes do
      { first_name: Faker::Name.first_name,
        last_name: Faker::Name.last_name,
        email: Faker::Internet.email }
    end
  end
end
