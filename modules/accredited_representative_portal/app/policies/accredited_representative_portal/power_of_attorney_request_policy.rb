# frozen_string_literal: true

module AccreditedRepresentativePortal
  module PilotAllowlist
    class << self
      def get_user_poa_codes(user)
        EMAIL_POA_CODES[user.email].to_a
      end

      ##
      # While the allowlist is non-existent, authorize every user. The allowlist
      # starts affecting authorization as soon as it has a single entry.
      #
      def inactive?
        EMAIL_POA_CODES.empty?
      end
    end

    EMAIL_POA_CODES =
      Settings
        .accredited_representative_portal
        .pilot_user_email_poa_codes.to_h
        .stringify_keys!
        .freeze
  end

  class PowerOfAttorneyRequestPolicy < ApplicationPolicy
    def show?
      authorize
    end

    def index?
      authorize
    end

    def create_decision?
      authorize
    end

    private

    def authorize
      return true if PilotAllowlist.inactive?

      ##
      # When the user is associated with any POA codes, then scenarios in which
      # they are trying to perform an operation against a POA request to which
      # they are not associated should be thought of as having an empty result
      # (`404`).
      #
      # However, when the user is not associated with any POA codes, then they
      # should be informed that they are not authorized to perform operations
      # against these resources.
      #
      user_poa_codes.empty?
    end

    def user_poa_codes
      @user_poa_codes ||= PilotAllowlist.get_user_poa_codes(@user)
    end

    class Scope < ApplicationPolicy::Scope
      def resolve
        return PowerOfAttorneyRequest if PilotAllowlist.inactive?

        PowerOfAttorneyRequest
          .preload(:power_of_attorney_holder)
          .where(power_of_attorney_holder: {
            poa_code: user_poa_codes
          })
      end

      private

      def user_poa_codes
        @user_poa_codes ||= PilotAllowlist.get_user_poa_codes(@user)
      end
    end
  end
end
