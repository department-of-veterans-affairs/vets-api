# frozen_string_literal: true

module ClaimsApi
  class EvidenceWaiverDocumentService < DocumentServiceBase
    LOG_TAG = 'Ews_Document_service'
    FORM_SUFFIX = '5103'

    def create_upload(claim:, pdf_path:, doc_type:, ptcpnt_vet_id:)
      validate_file_exists!(pdf_path, claim)

      body = generate_body(claim:, doc_type:, pdf_path:, ptcpnt_vet_id:)
      result = ClaimsApi::BD.new.upload_document(identifier: claim.claim_id, doc_type_name: FORM_SUFFIX, body:)

      ClaimsApi::Logger.log(LOG_TAG, ews_id: claim.id, claim_id: claim.claim_id,
                                     detail: 'Document upload to BD successful.')
      result
    rescue => e
      ClaimsApi::Logger.log(LOG_TAG, ews_id: claim.id, claim_id: claim.claim_id,
                                     detail: 'Document upload to BD failed.', error: e.message)
      raise e
    end

    private

    ##
    # Generate form body to upload a document
    #
    # @return {parameters, file}
    def generate_body(claim:, doc_type:, pdf_path:, ptcpnt_vet_id:)
      auth_headers = claim.auth_headers
      veteran_name = compact_name_for_file(auth_headers['va_eauth_firstName'],
                                           auth_headers['va_eauth_lastName'])
      tracked_item_ids = claim.tracked_items&.map(&:to_i) if claim&.has_attribute?(:tracked_items)

      generate_upload_body(claim_id: claim.claim_id, system_name: 'VA.gov', doc_type:, pdf_path:,
                           file_name: file_name(claim, veteran_name, FORM_SUFFIX), birls_file_number: nil,
                           participant_id: ptcpnt_vet_id, tracked_item_ids:)
    end

    def validate_file_exists!(pdf_path, claim)
      unless File.exist?(pdf_path)
        error_message = 'Evidence waiver PDF document not found for upload to Benefits Documents | ' \
                        "ews_id: #{claim&.id} | claim_id: #{claim&.claim_id}"
        ClaimsApi::Logger.log(LOG_TAG, detail: error_message)
        raise Errno::ENOENT, error_message
      end
    end
  end
end
