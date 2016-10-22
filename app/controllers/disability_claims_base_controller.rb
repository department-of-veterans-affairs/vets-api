# frozen_string_literal: true

class DisabilityClaimsBaseController < ApplicationController
  before_action :authorize_user

  protected

  def authorize_user
    head(403) unless @current_user.evss_attrs?
  end

  def claim_service
    @claim_service ||= DisabilityClaimService.new(@current_user)
  end
end
