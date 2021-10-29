# frozen_string_literal: true

module Okta
  # Wraps user response to simplify the interface to LOA data as it is stored in the user's profile.
  class UserProfile
    DSLOGON_PREMIUM_LOAS = %w[2 3].freeze
    MHV_PREMIUM_LOAS = %w[Premium].freeze

    def initialize(attrs)
      @attrs = attrs
    end

    attr_reader :attrs

    delegate :[], to: :attrs

    def derived_loa
      if @attrs['last_login_type'] == 'myhealthevet'
        ml = MHV_PREMIUM_LOAS.include?(@attrs['mhv_account_type']) ? 3 : 1
        { current: ml, highest: ml }
      elsif @attrs['last_login_type'] == 'dslogon'
        dl = DSLOGON_PREMIUM_LOAS.include?(@attrs['dslogon_assurance']) ? 3 : 1
        { current: dl, highest: dl }
      # SSOe combines LOA into a single field for all 3 login types
      elsif %w[200DOD 200VIDM 200MHV].include?(@attrs['last_login_type'])
        { current: @attrs['loa']&.to_i, highest: @attrs['loa']&.to_i }
      # Login.gov moves to IAL/AAL as the preferred method
      # Minimum IAL2 includes identity verification, AAL2 includes 2FA
      # Together will be treated as LOA3
      elsif @attrs['last_login_type'] == 'logingov'
        ial = @attrs['ial']&.to_i
        aal = @attrs['aal']&.to_i
        return { current: 1, highest: 1 } if ial.nil? || aal.nil?

        ll = ial >= 2 && aal >= 2 ? 3 : 1
        { current: ll, highest: ll }
      else
        { current: @attrs['idme_loa']&.to_i, highest: @attrs['idme_loa']&.to_i }
      end
    end
  end
end
