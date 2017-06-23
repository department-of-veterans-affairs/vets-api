# frozen_string_literal: true
module V0
  class DocumentsController < EVSSClaimsBaseController
    def create
      params.require :file
      claim = EVSSClaim.for_user(current_user).find_by(evss_id: params[:evss_claim_id])
      raise Common::Exceptions::RecordNotFound, params[:evss_claim_id] unless claim
      document_data = EVSSClaimDocument.new(
        evss_claim_id: claim.evss_id,
        file_obj: params[:file],
        file_name: params[:file].original_filename,
        tracked_item_id: params[:tracked_item_id],
        document_type: params[:document_type]
      )
      raise Common::Exceptions::ValidationErrors, document_data unless document_data.valid?
      if FeatureFlipper.evss_upload_workflow?
        upload = claim_service.upload_document(document_data)
        render_upload(upload)
      else
        jid = claim_service.upload_document(document_data)
        render_job_id(jid)
      end
    end
  end
end
