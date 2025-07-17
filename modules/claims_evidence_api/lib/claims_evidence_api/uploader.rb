# frozen_string_literal: true

require 'claims_evidence_api/exceptions'
require 'claims_evidence_api/service/files'
require 'pdf_utilities/pdf_stamper'

module ClaimsEvidenceApi
  class Uploader

    attr_accessor :content_source
    attr_reader :attempt, :response, :submission

    def initialize(folder_identifier, content_source: 'va.gov')
      @content_source = content_source
      @service = ClaimsEvidenceApi::Service::Files.new
      service.x_folder_uri = folder_identifier
    end

    def upload_saved_claim_evidence(saved_claim_id, claim_stamp_set = nil, attachment_stamp_set = nil)
      upload_saved_claim_pdf(saved_claim_id, nil, claim_stamp_set)
      claim.persistent_attachments.each { |pa| upload_attachment_pdf(saved_claim_id, pa.id, nil, attachment_stamp_set)}
    end

    def upload_saved_claim_pdf(saved_claim_id, pdf_path = nil, stamp_set = nil)
      claim = SavedClaim.find(saved_claim_id)
      init_tracking(saved_claim)
      perform_upload(claim, pdf_path, stamp_set)
      update_tracking
    end

    def upload_attachment_pdf(saved_claim_id, attachment_id, pdf_path = nil, stamp_set = nil)
      claim = SavedClaim.find(saved_claim_id)
      pa = PersistentAttachment.find_by(id: attachment_id, saved_claim_id:)
      init_tracking(claim, pa.id)
      perform_upload(pa, pdf_path, stamp_set)
      update_tracking
    end

    private

    def stamper(stamp_set)
      (stamp_set.class == 'String') ? PDFUtilities::PDFStamper.new(stamp_set) : PDFUtilities::PDFStamper.new(nil, stamps: stamp_set)
    end

    def init_tracking(saved_claim, persistent_attachment_id = nil)
      @submission = ClaimsEvidenceApi::Submission.find_or_create_by(saved_claim:, persistent_attachment_id:, form_id: saved_claim.form_id)
      submission.x_folder_uri = service.x_folder_uri
      submission.save

      @attempt = submission.submission_attempts.create
    end

    def perform_upload(evidence, pdf_path = nil, stamp_set = nil)
      pdf_path ||= evidence.to_pdf
      pdf_path = stamper(stamp_set).run(pdf_path, timestamp: evidence.created_at) if stamp_set
      submission.update_reference_data(pdf_path:)

      attempt.metadata = provider_data = {
        contentSource: content_source,
        dateVaReceivedDocument: evidence.created_at,
        documentTypeId: evidence.document_type
      }
      attempt.save

      @response = @service.upload(pdf_path, provider_data:)
    end

    def update_tracking
      unless response.success?
        attempt.status = 'failure'
        attempt.error_message = response.body
        attempt.save

        error_key = response.body.dig('messages', 'key') || response.body['code']
        error_msg = response.body.dig('messages', 'text') || response.body['message']
        raise ClaimsEvidenceApi::Exceptions::VefsError, "#{error_key} - #{error_msg}"
      end

      submission.file_uuid = response.body['uuid']
      submission.save

      attempt.status = 'accepted'
      attempt.response = response.body
      attempt.save

      response
    end
  end

  # end ClaimsEvidenceApi
end
