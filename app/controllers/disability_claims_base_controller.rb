# frozen_string_literal: true

class DisabilityClaimsBaseController < ApplicationController
  protected

  def claim_service
    @claim_service ||= DisabilityClaimService.new(@current_user)
  end
end
