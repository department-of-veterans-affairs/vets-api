# frozen_string_literal: true

require 'faraday'
require 'claims_api/v2/benefits_documents/service'

module ClaimsApi
  ##
  # Class to interact with the BRD API
  #
  class BD
    def initialize
      @multipart = false
      @use_mock = Settings.claims_api.benefits_documents.use_mocks || false
    end

    ##
    # Search documents by claim and file number
    #
    # @return Documents list
    def search(claim_id, file_number)
      @multipart = false
      body = { data: { claimId: claim_id, fileNumber: file_number } }
      ClaimsApi::Logger.log('benefits_documents',
                            detail: "calling benefits documents search for claimId #{claim_id}")
      res = client.post('documents/search', body)&.body

      raise ::Common::Exceptions::GatewayTimeout.new(detail: 'Upstream service error.') unless res.is_a?(Hash)

      res.deep_symbolize_keys
    rescue => e
      ClaimsApi::Logger.log('benefits_documents',
                            detail: "/search failure for claimId #{claim_id}, #{e.message}")
      {}
    end

    ##
    # Upload document of mapped claim
    #
    # @return success or failure
    # rubocop:disable Metrics/ParameterLists
    def upload(claim:, pdf_path:, pctpnt_vet_id: nil, doc_type: 'L122', file_number: nil, original_filename: nil)
      unless File.exist? pdf_path
        ClaimsApi::Logger.log('benefits_documents', detail: "Error uploading doc to BD: #{pdf_path} doesn't exist",
                                                    claim_id: claim.id)
        raise Errno::ENOENT, pdf_path
      end

      @multipart = true
      body = generate_upload_body(claim:, doc_type:, pdf_path:, file_number:, original_filename:, pctpnt_vet_id:)
      res = client.post('documents', body)&.body

      raise ::Common::Exceptions::GatewayTimeout.new(detail: 'Upstream service error.') unless res.is_a?(Hash)

      res = res.deep_symbolize_keys
      request_id = res.dig(:data, :requestId)
      ClaimsApi::Logger.log('benefits_documents',
                            detail: "Successfully uploaded #{doc_type == 'L122' ? 'claim' : 'supporting'} doc to BD",
                            claim_id: claim.id, request_id:)
      res
    rescue => e
      ClaimsApi::Logger.log('benefits_documents',
                            detail: "/upload failure for claimId #{claim.id}, #{e.message}")
      raise e
    end
    # rubocop:enable Metrics/ParameterLists

    private

    ##
    # Generate form body to upload a document
    #
    # @return {parameters, file}
    # rubocop:disable Metrics/ParameterLists
    def generate_upload_body(claim:, doc_type:, pdf_path:, pctpnt_vet_id: nil, file_number: nil, original_filename: nil)
      payload = {}
      auth_headers = claim.auth_headers
      veteran_name = "#{auth_headers['va_eauth_firstName']}_#{auth_headers['va_eauth_lastName']}"
      birls_file_num = auth_headers['va_eauth_birlsfilenumber'] || file_number if doc_type != 'L705'
      claim_id = doc_type == 'L705' ? claim.claim_id : claim.evss_id
      file_name = generate_file_name(doc_type:, veteran_name:, claim_id:, original_filename:)
      participant_id = pctpnt_vet_id if doc_type == 'L705'
      data = build_body(doc_type:, file_name:, participant_id:, claim_id:,
                        file_number: birls_file_num)

      fn = Tempfile.new('params')
      File.write(fn, data.to_json)
      payload[:parameters] = Faraday::UploadIO.new(fn, 'application/json')
      payload[:file] = Faraday::UploadIO.new(pdf_path.to_s, 'application/pdf')
      payload
    end

    # rubocop:enable Metrics/ParameterLists
    def generate_file_name(doc_type:, veteran_name:, claim_id:, original_filename:)
      # https://confluence.devops.va.gov/display/VAExternal/Document+Types
      if doc_type == 'L122'
        "#{veteran_name}_#{claim_id}_526EZ.pdf"
      elsif doc_type == 'L705'
        "#{veteran_name}_#{claim_id}_5103.pdf"
      else
        filename = get_original_supporting_doc_file_name(original_filename)
        "#{veteran_name}_#{claim_id}_#{filename}.pdf"
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

    ##
    # Configure Faraday base class (and do auth)
    #
    # @return Faraday client
    def client
      base_name = if Settings.claims_api&.benefits_documents&.host.nil?
                    'https://api.va.gov/services'
                  else
                    "#{Settings.claims_api&.benefits_documents&.host}/services"
                  end

      @token ||= ClaimsApi::V2::BenefitsDocuments::Service.new.get_auth_token
      raise StandardError, 'Benefits Docs token missing' if @token.blank? && !@use_mock

      Faraday.new("#{base_name}/benefits-documents/v1",
                  headers: { 'Authorization' => "Bearer #{@token}" }) do |f|
        f.request @multipart ? :multipart : :json
        f.response :betamocks if @use_mock
        f.response :raise_custom_error
        f.response :json, parser_options: { symbolize_names: true }
        f.adapter Faraday.default_adapter
      end
    end

    def build_body(doc_type:, file_name:, claim_id:, participant_id: nil, tracked_item_ids: [], file_number: nil) # rubocop:disable Metrics/ParameterLists
      data = {
        systemName: 'VA.gov',
        docType: doc_type,
        claimId: claim_id,
        fileName: file_name,
        trackedItemIds: tracked_item_ids
      }
      data[:participantId] = participant_id unless participant_id.nil?
      data[:fileNumber] = file_number unless file_number.nil?
      { data: }
    end
  end
end
