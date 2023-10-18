# frozen_string_literal: true

FactoryBot.define do
  factory :user_code_map, class: 'SignIn::UserCodeMap' do
    skip_create

    login_code { SecureRandom.uuid }
    type { SignIn::Constants::Auth::CSP_TYPES.first }
    client_state { SecureRandom.hex }
    client_config { create(:client_config) }
    terms_code { SecureRandom.uuid }

    initialize_with do
      new(login_code:,
          client_state:,
          client_config:,
          type:,
          terms_code:)
    end
  end
end
