# frozen_string_literal: true
module V0
  class DocumentsController < DisabilityClaimsBaseController
    def create
      params.require :file
      claim = DisabilityClaim.for_user(current_user).find(params[:disability_claim_id])
      document_data = DisabilityClaimDocument.new(
        evss_claim_id: claim.evss_id,
        file_name: params[:file].original_filename,
        tracked_item_id: params[:tracked_item_id],
        document_type: params[:document_type]
      )
      raise Common::Exceptions::ValidationErrors, document_data unless document_data.valid?
      jid = claim_service.upload_document(params[:file], document_data)
      render_job_id(jid)
    end
  end
end
