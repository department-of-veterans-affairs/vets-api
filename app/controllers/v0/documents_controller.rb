# frozen_string_literal: true
module V0
  class DocumentsController < ApplicationController
    skip_before_action :authenticate

    def create
      params.require :file
      claim = DisabilityClaim.for_user(current_user).find(params[:disability_claim_id])
      claim_service.upload_document(claim, params[:file], params[:tracked_item])
      head :no_content
    end

    private

    def claim_service
      @claim_service ||= DisabilityClaimService.new(current_user)
    end

    def current_user
      @current_user ||= User.sample_claimant
    end
  end
end
