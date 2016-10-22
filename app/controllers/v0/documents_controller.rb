# frozen_string_literal: true
module V0
  class DocumentsController < DisabilityClaimsBaseController
    def create
      params.require :file
      claim = DisabilityClaim.for_user(@current_user).find(params[:disability_claim_id])
      claim_service.upload_document(claim, params[:file], params[:tracked_item])
      head :no_content
    end
  end
end
