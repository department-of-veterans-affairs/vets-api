# frozen_string_literal: true

require 'claims_evidence_api/service/files'
require 'pdf_utilities/pdf_stamper'

module ClaimsEvidenceApi
  class Uploader

    def initialize(folder_identifier, content_source: 'va.gov')
      @content_source = content_source
      @service = ClaimsEvidenceApi::Service::Files.new
      service.x_folder_uri = folder_identifier
    end

    def upload_saved_claim_evidence(saved_claim_id, claim_stamp_set = nil, attachment_stamp_set = nil)
      upload_saved_claim_pdf(saved_claim_id, nil, claim_stamp_set)
      claim.persistent_attachments.each { |pa| upload_attachment_pdf(saved_claim_id, pa.id, nil, attachment_stamp_set)}
    end

    def upload_saved_claim_pdf(saved_claim_id, file_path = nil, stamp_set = nil)
      claim = SavedClaim.find(saved_claim_id)
      file_path ||= claim.to_pdf
      pdf_path = stamper(stamp_set).run(file_path, timestamp: claim.created_at) if stamp_set

      provider_data = {
        contentSource: content_source,
        dateVaReceivedDocument: claim.created_at,
        documentTypeId: claim.document_type
      }

      service.upload(pdf_path, provider_data:)
    end

    def upload_attachment_pdf(saved_claim_id, attachment_id, file_path = nil, stamp_set = nil)
      pa = PersistentAttachment.where(id: attachment_id, saved_claim_id:).first
      file_path ||= pa.to_pdf
      pdf_path = stamper(stamp_set).run(file_path, timestamp: pa.created_at) if stamp_set

      provider_data = {
        contentSource: content_source,
        dateVaReceivedDocument: pa.created_at,
        documentTypeId: pa.document_type
      }

      service.upload(pdf_path, provider_data:)
    end

    private

    attr_reader :content_source, :service

    def stamper(stamp_set)
      (stamp_set.class == 'Array') ? PDFUtilities::PDFStamper.new(nil, stamps: stamp_set) : PDFUtilities::PDFStamper.new(stamp_set)
    end

    def track_upload(saved_claim_id, persistent_attachment_id = nil)
      submission = ClaimsEvidenceApi::Submission.where(saved_claim_id:, persistent_attachment_id:).first
      submission = ClaimsEvidenceApi::Submission.new(saved_claim_id:, persistent_attachment_id:) unless submission

      submission.x_folder_uri = service.x_folder_uri

    end
  end

  # end ClaimsEvidenceApi
end
