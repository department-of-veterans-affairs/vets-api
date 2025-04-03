# frozen_string_literal: true

# Upload documents associated with a claim in the Claim Status Tool, to be sent to EVSS in a Job
module V0
  class DocumentsController < ApplicationController
    before_action { authorize :evss, :access? }
    service_tag 'claim-status'

    def create
      params.require :file
      claim = EVSSClaim.for_user(current_user).find_by(evss_id: params[:evss_claim_id])
      raise Common::Exceptions::RecordNotFound, params[:evss_claim_id] unless claim

      document_data = EVSSClaimDocument.new(
        evss_claim_id: claim.evss_id,
        file_obj: params[:file],
        uuid: SecureRandom.uuid,
        file_name: params[:file].original_filename,
        tracked_item_id: params[:tracked_item_id],
        document_type: params[:document_type],
        password: params[:password]
      )
      raise Common::Exceptions::ValidationErrors, document_data unless document_data.valid?

      document_data.upload(current_user)

      job_id = EVSS::DocumentUpload.perform_async(headers, @user.user_account_uuid,
                                                  evss_claim_document.to_serializable_hash, evidence_submission_id)
      record_workaround('document_upload', evss_claim_document.evss_claim_id, job_id) if headers_supplemented

      job_id

      # jid = service.upload_document(document_data)
      render_job_id(jid)
    end

    private

    def service
      EVSSClaimService.new(current_user)
    end
  end
end
