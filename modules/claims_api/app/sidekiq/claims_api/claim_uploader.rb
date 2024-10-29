# frozen_string_literal: true

require 'evss/documents_service'
require 'bd/bd'

module ClaimsApi
  class ClaimUploader < ClaimsApi::ServiceBase
    sidekiq_options retry: true, unique_until: :success

    def perform(uuid) # rubocop:disable Metrics/MethodLength
      claim_object = ClaimsApi::SupportingDocument.find_by(id: uuid) ||
                     ClaimsApi::AutoEstablishedClaim.find_by(id: uuid)

      auto_claim = claim_object.try(:auto_established_claim) || claim_object
      doc_type = claim_object.is_a?(ClaimsApi::SupportingDocument) ? 'L023' : 'L122'

      if auto_claim.evss_id.nil?
        ClaimsApi::Logger.log('lighthouse_claim_uploader',
                              detail: "evss id: #{auto_claim&.evss_id} was nil, for uuid: #{uuid}")
        self.class.perform_in(30.minutes, uuid)
      else
        auth_headers = auto_claim.auth_headers
        uploader = claim_object.uploader
        original_filename = claim_object.file_data['filename']
        uploader.retrieve_from_store!(original_filename)
        file_body = uploader.read
        ClaimsApi::Logger.log('lighthouse_claim_uploader', claim_id: auto_claim.id, attachment_id: uuid)
        if Flipper.enabled? :claims_claim_uploader_use_bd
          bd_upload_body(auto_claim:, file_body:, doc_type:, original_filename:)
        else
          EVSS::DocumentsService.new(auth_headers).upload(file_body, claim_upload_document(claim_object))
        end
      end
    end

    private

    def bd_upload_body(auto_claim:, file_body:, doc_type:, original_filename:)
      fh = Tempfile.new(['pdf_path', '.pdf'], binmode: true)
      begin
        fh.write(file_body)
        fh.close
        claim_bd_upload_document(auto_claim, doc_type, fh.path, original_filename)
      ensure
        fh.unlink
      end
    end

    def claim_bd_upload_document(claim, doc_type, pdf_path, original_filename) # rubocop:disable Metrics/MethodLength
      if Flipper.enabled? :claims_api_bd_refactor
        DisabilityCompensation::DisabilityDocumentService.new.create_upload(claim:, pdf_path:, doc_type:,
                                                                            original_filename:)
      else
        ClaimsApi::BD.new.upload(claim:, doc_type:, pdf_path:, original_filename:)
      end
    # Temporary errors (returning HTML, connection timeout), retry call
    rescue Faraday::ParsingError, Faraday::TimeoutError => e
      message = get_error_message(e)
      ClaimsApi::Logger.log('lighthouse_claim_uploader',
                            retry: true,
                            detail: "/upload failure for claimId #{claim&.id}: #{message}; error class: #{e.class}.")
      raise e
    # Check to determine if job should be retried based on status code
    rescue ::Common::Exceptions::BackendServiceException => e
      message = get_error_message(e)
      if will_retry_status_code?(e)
        ClaimsApi::Logger.log('lighthouse_claim_uploader',
                              retry: true,
                              detail: "/upload failure for claimId #{claim&.id}: #{message}; error class: #{e.class}.")
        raise e
      else
        ClaimsApi::Logger.log(
          'claims_api_sidekiq_failure',
          retry: false,
          claim_id: claim&.id.to_s,
          detail: 'ClaimUploader job failed',
          error: message
        )
        {}
      end
    # Permanent failures, don't retry
    rescue => e
      message = get_error_message(e)
      ClaimsApi::Logger.log('lighthouse_claim_uploader',
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
