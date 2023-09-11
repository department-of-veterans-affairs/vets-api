# frozen_string_literal: true

require 'lighthouse/benefits_documents/service'

module V0
  class BenefitsDocumentsController < ApplicationController
    before_action { authorize :lighthouse, :access? }
    Raven.tags_context(team: 'benefits-claim-appeal-status', feature: 'benefits-documents')

    def create
      params.require :file

      # Service expects a different claim ID param
      params[:claim_id] = params[:benefits_claim_id]

      jid = service.queue_document_upload(params)
      render_job_id(jid)
    end

    private

    def service
      BenefitsDocuments::Service.new(@current_user)
    end
  end
end
