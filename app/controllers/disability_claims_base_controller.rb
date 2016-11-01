# frozen_string_literal: true

class DisabilityClaimsBaseController < ApplicationController
  before_action :authorize_user

  protected

  def authorize_user
    unless current_user.can_access_evss?
      raise Common::Exceptions::Forbidden, detail: 'You do not have access to claim status'
    end
  end

  def claim_service
    @claim_service ||= DisabilityClaimService.new(current_user)
  end
end
