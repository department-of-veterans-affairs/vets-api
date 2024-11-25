# frozen_string_literal: true

module ClaimsApi
  class EvidenceWaiverDocumentService < DocumentServiceBase
    LOG_TAG = 'Ews_Document_service'
    FORM_SUFFIX = '5103'

    def create_upload(claim:, pdf_path:, doc_type:, ptcpnt_vet_id:)
      unless File.exist? pdf_path
        ClaimsApi::Logger.log(LOG_TAG, detail: "Error creating upload doc: #{pdf_path} doesn't exist,
                                                    claim_id: #{claim.claim_id}")
        raise Errno::ENOENT, pdf_path
      end

      body = generate_body(claim:, doc_type:, pdf_path:, ptcpnt_vet_id:)
      ClaimsApi::BD.new.upload_document(identifier: claim.claim_id, doc_type_name: '5103', body:)
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
  end
end
