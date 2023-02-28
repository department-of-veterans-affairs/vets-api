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

    initialize_with do
      new(acr: acr,
          code_challenge: code_challenge,
          client_state: client_state,
          client_id: client_id,
          type: type,
          code: code)
    end
  end
end
