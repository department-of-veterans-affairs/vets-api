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
      else
        { current: @attrs['idme_loa']&.to_i, highest: @attrs['idme_loa']&.to_i }
      end
    end
  end
end
