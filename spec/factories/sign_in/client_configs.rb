# frozen_string_literal: true

FactoryBot.define do
  factory :client_config, class: 'SignIn::ClientConfig' do
    client_id { SecureRandom.hex }
    authentication { SignIn::Constants::Auth::API }
    anti_csrf { false }
    pkce { true }
    certificates { [] }
    redirect_uri { Faker::Internet.url }
    logout_redirect_uri { Faker::Internet.url }
    access_token_duration { SignIn::Constants::AccessToken::VALIDITY_LENGTH_SHORT_MINUTES }
    access_token_audience { SecureRandom.hex }
    refresh_token_duration { SignIn::Constants::RefreshToken::VALIDITY_LENGTH_SHORT_MINUTES }
    description { Faker::Lorem.sentence }
    access_token_attributes { [] }
    json_api_compatibility { true }
    enforced_terms { SignIn::Constants::Auth::VA_TERMS }
    terms_of_use_url { Faker::Internet.url }
    shared_sessions { false }

    trait :with_certificates do
      ignore do
        certs_count { 1 }
      end

      after(:create) do |client_config, evaluator|
        create_list(:sign_in_config_certificate, evaluator.certs_count, config: client_config)
      end
    end
  end
end
