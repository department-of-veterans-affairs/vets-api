# frozen_string_literal: true

class DisabilityClaimsBaseController < ApplicationController
  skip_before_action :authenticate

  protected

  def claim_service
    @claim_service ||= DisabilityClaimService.new(current_user)
  end

  def current_user
    @current_user ||= User.sample_claimant
  end
end
