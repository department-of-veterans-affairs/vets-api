# frozen_string_literal: true
module V0
  class DocumentsController < ApplicationController
    skip_before_action :authenticate

    def create
      params.require :file
      claim = DisabilityClaim.for_user(current_user).find(params[:disability_claim_id])
      document_data = EVSS::DocumentData.new
      document_data.evss_claim_id = claim.evss_id
      document_data.file_name = params[:file].original_filename
      document_data.tracked_item_id = params[:tracked_item]
      document_data.document_type = params[:document_type]
      document_data.description = params[:document_description]
      jid = claim_service.upload_document(params[:file], document_data)
      render_job_id(jid)
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
