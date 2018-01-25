# frozen_string_literal: true

class EVSSClaimsBaseController < EVSSController
  protected

  def claim_service
    @claim_service ||= EVSSClaimService.new(current_user)
  end
end
