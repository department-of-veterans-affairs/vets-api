# frozen_string_literal: true

FactoryBot.define do
  factory :state_payload, class: 'SignIn::StatePayload' do
    skip_create

    acr { SignIn::Constants::Auth::ACR_VALUES.first }
    client_id { create(:client_config).client_id }
    type { SignIn::Constants::Auth::CSP_TYPES.first }
    code_challenge { Base64.urlsafe_encode64(SecureRandom.hex) }
    client_state { SecureRandom.hex }
    code { SecureRandom.hex }
    created_at { Time.zone.now.to_i }
    scope { SignIn::Constants::Auth::DEVICE_SSO }
    operation { SignIn::Constants::Auth::VERIFY_CTA_AUTHENTICATED }

    initialize_with do
      new(acr:,
          code_challenge:,
          client_state:,
          client_id:,
          type:,
          code:,
          created_at:,
          scope:,
          operation:)
    end
  end
end
