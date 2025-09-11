# frozen_string_literal: true

# TEST FILE: Controller changes that should NOT be allowed with migrations
# For testing the MigrationIsolator Dangerfile changes
# DO NOT MERGE THIS FILE - For testing only

module V0
  class ClaimsControllerTest < ApplicationController
    before_action :authenticate
    
    def index
      # NEW BUSINESS LOGIC using the new columns
      @claims = Claim.where(processing_status: params[:status])
                     .order(processed_at: :desc)
      render json: @claims
    end
    
    def update_status
      # NEW ENDPOINT that depends on the migration
      @claim = Claim.find(params[:id])
      @claim.update!(
        processing_status: params[:status],
        processed_at: Time.current,
        processor_id: current_user.uuid
      )
      
      ClaimStatusMailer.status_changed(@claim).deliver_later
      render json: @claim
    end
    
    private
    
    def claim_params
      params.require(:claim).permit(:processing_status, :processor_id)
    end
  end
end