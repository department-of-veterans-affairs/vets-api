# frozen_string_literal: true

module ClaimsApi
  class PoaDocumentService < DocumentServiceBase
    LOG_TAG = 'Poa_Document_service'

    def create_upload(poa:, pdf_path:, doc_type:, action:)
      unless File.exist? pdf_path
        ClaimsApi::Logger.log(LOG_TAG, detail: "Error creating upload doc: #{pdf_path} doesn't exist,
                                                    poa_id: #{poa.id}")
        raise Errno::ENOENT, pdf_path
      end

      body = generate_body(poa:, doc_type:, pdf_path:, action:)
      ClaimsApi::BD.new.upload_document(identifier: poa.id, doc_type_name: 'POA', body:)
    end

    private

    ##
    # Generate form body to upload a document
    #
    # @return {parameters, file}
    def generate_body(poa:, doc_type:, pdf_path:, action:)
      auth_headers = poa.auth_headers
      veteran_name = compact_veteran_name(auth_headers['va_eauth_firstName'],
                                          auth_headers['va_eauth_lastName'])
      ptcpnt_vet_id = auth_headers['va_eauth_pid']
      participant_id = find_ptcpnt_vet_id(auth_headers, ptcpnt_vet_id)
      form_name = get_form_name(action:, doc_type:)
      file_name = build_file_name(veteran_name:, identifier: nil, suffix: form_name)

      generate_upload_body(claim_id: nil, system_name: 'Lighthouse', doc_type:, pdf_path:, file_name:,
                           birls_file_number: nil, participant_id:, tracked_item_ids: nil)
    end

    def get_form_name(action:, doc_type:)
      doc_type_form_names = {
        'put' => {
          'L075' => 'representative',
          'L190' => 'representative'
        },
        'post' => {
          'L075' => '21-22a',
          'L190' => '21-22'
        }
      }

      doc_type_form_names[action][doc_type]
    end
  end
end
