# frozen_string_literal: true

module AccreditedRepresentativePortal
  class AuthorizationPolicy < ApplicationPolicy
    def self.policy_name
      'AccreditedRepresentativePortal::Authorization'
    end

    def authorize_as_representative?
      # Must be logged in is enforced by ApplicationPolicy initialize
      # Authorize only if the current user's account maps to any POA holders
      @user.representative?
    rescue Common::Exceptions::Forbidden
      false
    end
  end
end
