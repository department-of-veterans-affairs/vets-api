# frozen_string_literal: true

module ClaimsApi
  module DisabilityCompensation
    class DisabilityDocumentService < DocumentServiceBase
      LOG_TAG = '526_v2_Disability_Document_service'

      def create_upload(claim:, pdf_path:, doc_type: 'L122', original_filename: nil)
        unless File.exist? pdf_path
          ClaimsApi::Logger.log('benefits_documents', detail: "Error creating upload doc: #{file_path} doesn't exist,
                                                      claim_id: #{claim.id}")
          raise Errno::ENOENT, pdf_path
        end

        body = generate_body(claim:, doc_type:, pdf_path:, original_filename:)
        doc_type_name = doc_type_to_plain_language(doc_type)
        ClaimsApi::BD.new.upload_document(claim_id: claim.id, doc_type:, doc_type_name:, body:)
      end

      private

      ##
      # Generate form body to upload a document
      #
      # @return {parameters, file}
      def generate_body(claim:, doc_type:, pdf_path:, original_filename: nil)
        auth_headers = claim.auth_headers
        veteran_name = compact_veteran_name(auth_headers['va_eauth_firstName'],
                                            auth_headers['va_eauth_lastName'])
        birls_file_number = auth_headers['va_eauth_birlsfilenumber']
        claim_id = claim.evss_id
        form_name = '526EZ' if doc_type == 'L122'
        file_name = generate_file_name(veteran_name:, claim_id:, form_name:, original_filename:)
        system_name = 'VA.gov'
        tracked_item_ids = claim.tracked_items&.map(&:to_i) if claim&.has_attribute?(:tracked_items)

        generate_upload_body(claim_id:, system_name:, doc_type:, pdf_path:, file_name:, birls_file_number:,
                             participant_id: nil, tracked_item_ids:)
      end

      def generate_file_name(veteran_name:, claim_id:, form_name:, original_filename:)
        if form_name == '526EZ'
          "#{[veteran_name, claim_id, form_name].compact_blank.join('_')}.pdf"
        else
          filename = get_original_supporting_doc_file_name(original_filename)
          "#{[veteran_name, claim_id, filename].compact_blank.join('_')}.pdf"
        end
      end

      ##
      # DisabilityCompensationDocuments method create_unique_filename adds a random 11 digit
      # hex string to the original filename, so we remove that to yield the user-submitted
      # filename to use as part of the filename uploaded to the BD service.
      def get_original_supporting_doc_file_name(original_filename)
        file_extension = File.extname(original_filename)
        base_filename = File.basename(original_filename, file_extension)
        base_filename[0...-12]
      end

      def doc_type_to_plain_language(doc_type)
        case doc_type
        when 'L122'
          'claim'
        else
          'supporting'
        end
      end
    end
  end
end
