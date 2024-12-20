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
    def upload(claim:, pdf_path:, doc_type: 'L122', action: 'post', original_filename: nil, # rubocop:disable Metrics/ParameterLists
               pctpnt_vet_id: nil)
      unless File.exist? pdf_path
        ClaimsApi::Logger.log('benefits_documents', detail: "Error uploading doc to BD: #{pdf_path} doesn't exist,
                                                    #{doc_type_to_plain_language(doc_type)}_id: #{claim.id}")
        raise Errno::ENOENT, pdf_path
      end

      @multipart = true
      body = generate_upload_body(claim:, doc_type:, pdf_path:, action:, original_filename:,
                                  pctpnt_vet_id:)
      res = client.post('documents', body)&.body

      raise ::Common::Exceptions::GatewayTimeout.new(detail: 'Upstream service error.') unless res.is_a?(Hash)

      res = res.deep_symbolize_keys
      request_id = res.dig(:data, :requestId)
      ClaimsApi::Logger.log('benefits_documents',
                            detail: "Successfully uploaded #{doc_type_to_plain_language(doc_type)} doc to BD,
                                                    #{doc_type_to_plain_language(doc_type)}_id: #{claim.id}",
                            request_id:)
      res
    rescue => e
      ClaimsApi::Logger.log('benefits_documents',
                            detail: "/upload failure for
                                                    #{doc_type_to_plain_language(doc_type)}_id: #{claim.id},
                                                    #{e.message}")
      raise e
    end

    def upload_document(identifier:, doc_type_name:, body:)
      @multipart = true
      res = client.post('documents', body)&.body

      raise ::Common::Exceptions::GatewayTimeout.new(detail: 'Upstream service error.') unless res.is_a?(Hash)

      res = res.deep_symbolize_keys
      request_id = res.dig(:data, :requestId)
      ClaimsApi::Logger.log('benefits_documents',
                            detail: "Successfully uploaded #{doc_type_name} doc to BD,
                                                   #{doc_type_name}_id: #{identifier}",
                            request_id:)
      res
    rescue => e
      ClaimsApi::Logger.log('benefits_documents',
                            detail: "/upload failure for
                                                    #{doc_type_name}_id: #{identifier},
                                                    #{e.message}")
      raise e
    end

    private

    def doc_type_to_plain_language(doc_type)
      case doc_type
      when 'L075', 'L190'
        'POA'
      when 'L122'
        'claim'
      else
        'supporting'
      end
    end

    def compact_veteran_name(first_name, last_name)
      [first_name, last_name].compact_blank.join('_')
    end

    def get_claim_id(doc_type, claim)
      case doc_type
      when 'L075', 'L190'
        nil
      when 'L705'
        claim.claim_id
      else
        claim.evss_id
      end
    end

    ##
    # Generate form body to upload a document
    #
    # @return {parameters, file}
    # rubocop:disable Metrics/ParameterLists
    def generate_upload_body(claim:, doc_type:, pdf_path:, action:, original_filename: nil,
                             pctpnt_vet_id: nil)
      payload = {}
      auth_headers = claim.auth_headers
      veteran_name = compact_veteran_name(auth_headers['va_eauth_firstName'],
                                          auth_headers['va_eauth_lastName'])
      birls_file_num = determine_birls_file_number(doc_type, auth_headers)
      claim_id = get_claim_id(doc_type, claim)
      file_name = generate_file_name(doc_type:, veteran_name:, claim_id:, original_filename:, action:)
      participant_id = find_pctpnt_vet_id(auth_headers, pctpnt_vet_id) if %w[L075 L190 L705].include?(doc_type)
      system_name = 'Lighthouse' if %w[L075 L190].include?(doc_type)
      tracked_item_ids = claim.tracked_items&.map(&:to_i) if claim&.has_attribute?(:tracked_items)
      data = build_body(doc_type:, file_name:, participant_id:, claim_id:,
                        file_number: birls_file_num, system_name:, tracked_item_ids:)

      fn = Tempfile.new('params')
      File.write(fn, data.to_json)
      payload[:parameters] = Faraday::UploadIO.new(fn, 'application/json')
      payload[:file] = Faraday::UploadIO.new(pdf_path.to_s, 'application/pdf')
      payload
    end

    def determine_birls_file_number(doc_type, auth_headers)
      if %w[L122].include?(doc_type)
        birls_file_num = auth_headers['va_eauth_birlsfilenumber']
      elsif %w[L075 L190 L705].include?(doc_type)
        birls_file_num = nil
      end
      birls_file_num
    end
    # rubocop:enable Metrics/ParameterLists

    def generate_file_name(doc_type:, veteran_name:, claim_id:, original_filename:, action:)
      # https://confluence.devops.va.gov/display/VAExternal/Document+Types
      doc_type_names = {
        'put' => {
          'L075' => 'representative',
          'L190' => 'representative'
        },
        'post' => {
          'L075' => '21-22a',
          'L122' => '526EZ',
          'L190' => '21-22',
          'L705' => '5103'
        }
      }

      form_name = doc_type_names[action][doc_type]

      if form_name
        "#{[veteran_name, claim_id, form_name].compact_blank.join('_')}.pdf"
      else
        filename = get_original_supporting_doc_file_name(original_filename)
        "#{[veteran_name, claim_id, filename].compact_blank.join('_')}.pdf"
      end
    end

    def find_pctpnt_vet_id(auth_headers, pctpnt_vet_id)
      pctpnt_vet_id.presence || auth_headers['va_eauth_pid']
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

    def build_body(options = {})
      data = {
        systemName: options[:system_name].presence || 'VA.gov',
        docType: options[:doc_type],
        fileName: options[:file_name],
        trackedItemIds: options[:tracked_item_ids].presence || []
      }
      data[:claimId] = options[:claim_id] unless options[:claim_id].nil?
      data[:participantId] = options[:participant_id] unless options[:participant_id].nil?
      data[:fileNumber] = options[:file_number] unless options[:file_number].nil?
      { data: }
    end
  end
end
