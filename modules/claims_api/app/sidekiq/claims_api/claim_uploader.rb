# frozen_string_literal: true

require 'sidekiq'
require 'evss/documents_service'
require 'claims_api/claim_logger'
require 'bd/bd'

module ClaimsApi
  class ClaimUploader
    include Sidekiq::Job

    sidekiq_options retry: true, unique_until: :success

    sidekiq_retries_exhausted do |message|
      ClaimsApi::Logger.log(
        'claims_api_retries_exhausted',
        claim_id: message['args'].first,
        detail: "Job retries exhausted for #{message['class']}",
        error: message['error_message']
      )
    end

    def perform(uuid)
      claim_object = ClaimsApi::SupportingDocument.find_by(id: uuid) ||
                     ClaimsApi::AutoEstablishedClaim.find_by(id: uuid)

      auto_claim = claim_object.try(:auto_established_claim) || claim_object
      doc_type = claim_object.is_a?(ClaimsApi::SupportingDocument) ? 'L023' : 'L122'

      if auto_claim.evss_id.nil?
        ClaimsApi::Logger.log('claims_uploader', detail: "evss id: #{auto_claim&.evss_id} was nil, for uuid: #{uuid}")
        self.class.perform_in(30.minutes, uuid)
      else
        auth_headers = auto_claim.auth_headers
        uploader = claim_object.uploader
        uploader.retrieve_from_store!(claim_object.file_data['filename'])
        file_body = uploader.read
        ClaimsApi::Logger.log('526', claim_id: auto_claim.id, attachment_id: uuid)
        if Flipper.enabled? :claims_claim_uploader_use_bd
          bd_upload_body(auto_claim:, file_body:, doc_type:)
        else
          EVSS::DocumentsService.new(auth_headers).upload(file_body, claim_upload_document(claim_object))
        end
      end
    end

    private

    def bd_upload_body(auto_claim:, file_body:, doc_type:)
      fh = Tempfile.new(['pdf_path', '.pdf'], binmode: true)
      begin
        fh.write(file_body)
        fh.close
        claim_bd_upload_document(auto_claim, doc_type, fh.path)
      ensure
        fh.unlink
      end
    end

    def claim_bd_upload_document(claim, doc_type, pdf_path)
      ClaimsApi::BD.new.upload(claim:, doc_type:, pdf_path:)
    # Temporary errors (returning HTML, connection timeout), retry call
    rescue Faraday::ParsingError, Faraday::TimeoutError => e
      ClaimsApi::Logger.log('benefits_documents',
                            retry: true,
                            detail: "/upload failure for claimId #{claim&.id}: #{e.message}; error class: #{e.class}.")
      raise e
    # Permanent failures, don't retry
    rescue => e
      message = if e.respond_to? :original_body
                  e.original_body
                else
                  e.message
                end
      ClaimsApi::Logger.log('benefits_documents',
                            retry: false,
                            detail: "/upload failure for claimId #{claim&.id}: #{message}; error class: #{e.class}.")
      {}
    end

    def claim_upload_document(claim_document)
      upload_document = OpenStruct.new(
        file_name: claim_document.file_name,
        document_type: claim_document.document_type,
        description: claim_document.description
      )

      if claim_document.is_a? ClaimsApi::SupportingDocument
        upload_document.evss_claim_id = claim_document.evss_claim_id
        upload_document.tracked_item_id = claim_document.tracked_item_id
      else # then it's a ClaimsApi::AutoEstablishedClaim
        upload_document.evss_claim_id = claim_document.evss_id
        upload_document.tracked_item_id = claim_document.id
      end

      upload_document
    end
  end
end
