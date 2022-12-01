# frozen_string_literal: true

FactoryBot.define do
  factory :credential_level, class: 'SignIn::CredentialLevel' do
    skip_create

    requested_acr { SignIn::Constants::Auth::ACR_VALUES.first }
    current_ial { IAL::ONE }
    max_ial { IAL::ONE }
    credential_type { SignIn::Constants::Auth::CSP_TYPES.first }
    auto_uplevel { false }

    initialize_with do
      new(requested_acr: requested_acr,
          current_ial: current_ial,
          max_ial: max_ial,
          credential_type: credential_type,
          auto_uplevel: auto_uplevel)
    end
  end
end
