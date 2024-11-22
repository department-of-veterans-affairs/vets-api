# frozen_string_literal: true

module AccreditedRepresentativePortal
  class PowerOfAttorneyRequestsPolicy
    def initialize(user, poa_request)
      @user = user
      @poa_request = poa_request
    end

    def pilot_users
      Settings.accredited_representative_portal.pilot_users.to_h.stringify_keys
    end

    def authorize
      return false unless @user

      allowed_codes = Array(pilot_users[@user.email])
      return false unless allowed_codes

      if @poa_request.is_a?(Array)
        @poa_request.all? { |request| allowed_codes.include?(request.poa_code) }
      else
        allowed_codes.include?(@poa_request.poa_code)
      end
    end
  end
end
