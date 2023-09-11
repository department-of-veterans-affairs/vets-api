# frozen_string_literal: true

require 'common/client/configuration/rest'
require 'lighthouse/auth/client_credentials/jwt_generator'
require 'lighthouse/auth/client_credentials/service'

module BenefitsDocuments
  ##
  # HTTP client configuration for the {BenefitsClaims::Service},
  # sets the base path, the base request headers, and a service name for breakers and metrics.
  #
  class Configuration < Common::Client::Configuration::REST
    self.read_timeout = Settings.lighthouse.benefits_documents.timeout || 20

    SYSTEM_NAME = 'VA.gov'
    API_SCOPES = %w[documents.read documents.write].freeze
    DOCUMENTS_PATH = 'services/benefits-documents/v1/documents'
    TOKEN_PATH = 'oauth2/benefits-documents/system/v1/token'

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
          docType: document_data[:document_type],
          claimId: document_data[:claim_id],
          fileNumber: document_data[:file_number],
          fileName: document_data[:file_name],
          # In theory one document can correspond to multiple tracked items
          # To do that, add multiple query parameters
          trackedItemIds: document_data[:tracked_item_id]
        }
      }

      payload[:parameters] = data
      fn = Tempfile.new('params')
      File.write(fn, data.to_json)
      payload[:parameters] = Faraday::UploadIO.new(fn, 'application/json')

      file = Tempfile.new(document_data[:file_name])
      File.write(file, file_body)
      payload[:file] = Faraday::UploadIO.new(file, 'application/pdf')
      payload
    end

    ##
    # Creates a Faraday connection with parsing json and breakers functionality.
    #
    # @return [Faraday::Connection] a Faraday connection instance.
    #
    def connection
      @conn ||= Faraday.new(base_api_path, headers: base_request_headers, request: request_options) do |faraday|
        faraday.use :breakers
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
  end
end
