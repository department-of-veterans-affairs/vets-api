# frozen_string_literal: true

FactoryBot.define do
  factory :credential_info, class: 'SignIn::CredentialInfo' do
    id_token { SecureRandom.hex }
    csp_uuid { SecureRandom.uuid }
    credential_type { SignIn::Constants::Auth::REDIRECT_URLS.first }
  end
end
