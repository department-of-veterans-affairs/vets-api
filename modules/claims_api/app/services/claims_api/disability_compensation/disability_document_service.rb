# frozen_string_literal: true

module ClaimsApi
  module DisabilityCompensation
    class DisabilityDocumentService < DocumentServiceBase
      LOG_TAG = '526_v2_Disability_Document_service'

      def create_upload(claim:, pdf_path:, doc_type: 'L122', action: 'post', original_filename: nil)
        unless File.exist? pdf_path
          ClaimsApi::Logger.log('benefits_documents', detail: "Error creating upload doc: #{file_path} doesn't exist,
                                                      claim_id: #{claim.id}")
          raise Errno::ENOENT, pdf_path
        end

        body = generate_upload_body(claim:, doc_type:, pdf_path:, action:, original_filename:)
        ClaimsApi::BD.new.upload_document(claim_id: claim.id, doc_type:, body:)
      end

      private

      ##
      # Generate form body to upload a document
      #
      # @return {parameters, file}
      def generate_upload_body(claim:, doc_type:, pdf_path:, action:, original_filename: nil)
        payload = {}
        auth_headers = claim.auth_headers
        veteran_name = compact_veteran_name(auth_headers['va_eauth_firstName'], auth_headers['va_eauth_lastName'])
        birls_file_num = auth_headers['va_eauth_birlsfilenumber']
        claim_id = claim.evss_id
        file_name = generate_file_name(doc_type:, veteran_name:, claim_id:, original_filename:, action:)
        tracked_item_ids = claim.tracked_items&.map(&:to_i) if claim&.has_attribute?(:tracked_items)
        data = build_body(doc_type:, file_name:, claim_id:,
                          file_number: birls_file_num, tracked_item_ids:)

        fn = Tempfile.new('params')
        File.write(fn, data.to_json)
        payload[:parameters] = Faraday::UploadIO.new(fn, 'application/json')
        payload[:file] = Faraday::UploadIO.new(pdf_path.to_s, 'application/pdf')
        payload
      end

      def generate_file_name(doc_type:, veteran_name:, claim_id:, original_filename:, action:)
        if action == 'post' && doc_type == 'L122'
          "#{[veteran_name, claim_id, '526EZ'].compact_blank.join('_')}.pdf"
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
    end
  end
end
