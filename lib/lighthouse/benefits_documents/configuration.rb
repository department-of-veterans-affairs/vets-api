# frozen_string_literal: true

require 'common/client/configuration/rest'
require 'faraday/multipart'
require 'lighthouse/auth/client_credentials/jwt_generator'
require 'lighthouse/auth/client_credentials/service'

module BenefitsDocuments
  ##
  # HTTP client configuration for the {BenefitsClaims::Service},
  # sets the base path, the base request headers, and a service name for breakers and metrics.
  #
  class Configuration < Common::Client::Configuration::REST
    self.read_timeout = Settings.lighthouse.benefits_documents.timeout || 65

    SYSTEM_NAME = 'VA.gov'
    API_SCOPES = %w[documents.read documents.write].freeze
    BASE_PATH = 'services/benefits-documents/v1'
    DOCUMENTS_PATH = "#{BASE_PATH}/documents".freeze
    DOCUMENTS_STATUS_PATH = "#{BASE_PATH}/uploads/status".freeze
    CLAIMS_LETTERS_SEARCH_PATH = "#{BASE_PATH}/claim-letters/search".freeze
    CLAIMS_LETTER_DOWNLOAD_PATH = "#{BASE_PATH}/claim-letters/download".freeze
    TOKEN_PATH = 'oauth2/benefits-documents/system/v1/token'
    QA_TESTING_DOMAIN = Settings.lighthouse.benefits_documents.host

    ##
    # @return [Config::Options] Settings for benefits_claims API.
    #
    def documents_settings
      Settings.lighthouse.benefits_documents
    end

    def global_settings
      Settings.lighthouse.auth
    end

    ##
    # @param [String] host (optional): a configurable base url host if the client application does not want to
    #   use the default
    # @return [String] Base path for veteran_verification URLs.
    #
    def base_path(host = nil)
      (host || documents_settings.host).to_s
    end

    def base_api_path(host = nil)
      "#{base_path(host)}/"
    end

    ##
    # @return [String] Service name to use in breakers and metrics.
    #
    def service_name
      'BenefitsDocuments'
    end

    ##
    # @return [Faraday::Response] response from POST request
    #
    def post(file_body, document_data, lighthouse_client_id = nil, lighthouse_rsa_key_path = nil, options = {})
      headers = { 'Authorization' => "Bearer #{
        access_token(
          lighthouse_client_id,
          lighthouse_rsa_key_path,
          options
        )
      }",
                  'Content-Type' => 'multipart/form-data' }

      body = generate_upload_body(document_data, file_body)
      connection.post(DOCUMENTS_PATH, body, headers)
    end

    def generate_upload_body(document_data, file_body)
      payload = {}
      data = {
        data: {
          systemName: SYSTEM_NAME,
          docType: document_data.document_type,
          claimId: document_data.claim_id,
          participantId: document_data.participant_id,
          fileName: document_data.file_name,
          # In theory one document can correspond to multiple tracked items
          # To do that, add multiple query parameters
          trackedItemIds: document_data.tracked_item_id
        }
      }

      payload[:parameters] = Faraday::Multipart::ParamPart.new(
        data.to_json,
        'application/json'
      )

      file = Tempfile.new(document_data.file_name)
      File.write(file, file_body)

      mime_type = MimeMagic.by_path(document_data.file_name).type
      payload[:file] = Faraday::UploadIO.new(file, mime_type)

      payload
    end

    def get_documents_status(lighthouse_document_request_ids)
      headers = {
        'Authorization' => "Bearer #{documents_status_access_token}",
        'Content-Type' => 'application/json'
      }

      body = {
        data: {
          requestIds: lighthouse_document_request_ids
        }
      }.to_json

      documents_status_api_connection.post(DOCUMENTS_STATUS_PATH, body, headers)
    end

    # Returns the identifying information for all Claims Evidence claim letter documents
    # that are eligible to be downloaded via the Documents Service,
    # identified the fileNumber or participantId.
    # @param doc_type_ids: string The numeric code of the types of documents to search for.
    # If not provided, then all downloadable claim letter documents matching the other request criteria will be returned.
    # @param participant_id: string A unique identifier assigned to each patient entry in the
    # Master Patient Index linking patients to their records across VA systems.
    # Example: 999012105
    # @param file_number: string The Veteran's VBMS fileNumber used when uploading the document
    # to VBMS. It indicates the eFolder in which the document resides. Example: 999012105
    def claim_letters_search(doc_type_ids: nil, participant_id: nil, file_number: nil)
      headers = { 'Authorization' => "Bearer #{
          access_token(
            nil,
            nil,
            {}
          )
        }" }

      body = {
        'data' => {
          'docTypeIds' => doc_type_ids,
          'fileNumber' => file_number,
          'participantId' => participant_id
        }
      }
      connection.post(CLAIMS_LETTERS_SEARCH_PATH, body, headers)
    end

    # Downloads the binary content for the Claims Evidence claim letter document that is
    # identified by the given documentId and associated with the given
    # participantId or fileNumber.
    # Note that downloading file content is only supported for certain document types.
    # @param document_uuid: string The document's unique identifier in VBMS,
    # obtained by making a Document Service API request to search for documents
    # that are available to download for the Veteran.
    # Note that this differs from the document's current version UUID.
    # Example: "12345678-ABCD-0123-cdef-124345679ABC"
    # @param participant_id: string A unique identifier assigned to each patient entry
    # in the Master Patient Index linking patients to their records across VA systems.
    # Example: 999012105
    # @param file_number: The Veteran's VBMS fileNumber used when uploading the document to VBMS.
    # It indicates the eFolder in which the document resides.
    # Example: 999012105
    def claim_letter_download(document_uuid: nil, participant_id: nil, file_number: nil)
      headers = { 'Authorization' => "Bearer #{
          access_token(
            nil,
            nil,
            {}
          )
        }", 'Accept' => 'application/octet-stream, application/json' }

      body = {
        'data' => {
          'fileNumber' => file_number,
          'participantId' => participant_id,
          'documentUuid' => document_uuid
        }
      }
      connection.post(CLAIMS_LETTER_DOWNLOAD_PATH, body, headers)
    end

    ##
    # Creates a Faraday connection with parsing json and breakers functionality.
    #
    # @return [Faraday::Connection] a Faraday connection instance.
    #
    def connection(api_path = base_api_path)
      @conn ||= Faraday.new(api_path, headers: base_request_headers, request: request_options) do |faraday|
        faraday.use(:breakers, service_name:)
        faraday.use Faraday::Response::RaiseError

        faraday.request :multipart
        faraday.request :json

        faraday.response :betamocks if use_mocks?
        faraday.response :json, content_type: /\bjson/
        faraday.adapter Faraday.default_adapter
      end
    end

    private

    ##
    # @return [Boolean] Should the service use mock data in lower environments.
    #
    def use_mocks?
      documents_settings.use_mocks || false
    end

    def get_access_token?
      !use_mocks? || Settings.betamocks.recording
    end

    def access_token(lighthouse_client_id = nil, lighthouse_rsa_key_path = nil, options = {})
      if get_access_token?
        token_service(
          lighthouse_client_id,
          lighthouse_rsa_key_path,
          options[:aud_claim_url],
          options[:host]
        ).get_token(options[:auth_params])
      end
    end

    ##
    # @return [BenefitsClaims::AccessToken::Service] Service used to generate access tokens.
    #
    def token_service(lighthouse_client_id, lighthouse_rsa_key_path, aud_claim_url = nil, host = nil)
      lighthouse_client_id = global_settings.ccg.client_id if lighthouse_client_id.nil?
      lighthouse_rsa_key_path = global_settings.ccg.rsa_key if lighthouse_rsa_key_path.nil?
      host ||= base_path(host)
      url = "#{host}/#{TOKEN_PATH}"
      aud_claim_url ||= documents_settings.access_token.aud_claim_url

      @token_service ||= Auth::ClientCredentials::Service.new(
        url, API_SCOPES, lighthouse_client_id, aud_claim_url, lighthouse_rsa_key_path, 'benefits-documents'
      )
    end

    def documents_status_access_token
      # Lighthouse requires the documents status endpoint be tested on the QA testing domain
      ENV['RAILS_ENV'] == 'test' ? access_token(nil, nil, { host:  QA_TESTING_DOMAIN }) : access_token
    end

    def documents_status_api_connection
      # Lighthouse requires the documents status endpoint be tested on the QA testing domain
      ENV['RAILS_ENV'] == 'test' ? connection(QA_TESTING_DOMAIN) : connection
    end
  end
end
