# frozen_string_literal: true

require 'evss_service/base'
require 'faraday'

module ClaimsApi
  ##
  # Class to interact with the BRD API
  #
  # Takes an optional request parameter
  # @param [] rails request object
  class BD
    def initialize(request = nil)
      @request = request
    end

    ##
    # Upload document of mapped claim
    #
    # @return success or failure
    def upload(claim, pdf_path, file_number)
      body = generate_upload_body(claim, pdf_path, file_number)
      client.post('documents', body)&.body
    end

    ##
    # Generate form body to upload a document
    #
    # @return {paramenters, file}
    def generate_upload_body(claim, pdf_path, file_number)
      payload = {}
      data = {
        data: {
          systemName: 'va.gov',
          docType: 'L122',
          claimId: claim.evss_id,
          fileNumber: file_number,
          fileName: File.basename(pdf_path),
          trackedItemIds: []
        }
      }
      payload[:parameters] = data
      fn = Tempfile.new('params')
      File.write(fn, data.to_json)
      payload[:parameters] = Faraday::UploadIO.new(fn, 'application/json')
      payload[:file] = Faraday::UploadIO.new(pdf_path, 'application/pdf')
      payload
    end

    private

    ##
    # Configure Faraday base class (and do auth)
    #
    # @return Faraday client
    def client
      base_name = if !Settings.bd&.base_name.nil?
                    Settings.bd.base_name
                  elsif @request&.host_with_port.nil?
                    'api.va.gov/services'
                  else
                    "#{@request&.host_with_port}/services"
                  end

      token = ClaimsApi::EVSSService::Token.new.get_token # TODO: move this to generalized token service when it's ready
      raise StandardError, 'Benefits Docs api_oauth_client_id missing' if token.blank?

      Faraday.new("https://#{base_name}/benefits-documents/v1",
                  # Disable SSL for (localhost) testing
                  ssl: { verify: Settings.bd&.ssl != false },
                  headers: { 'Authorization' => "Bearer #{token}" }) do |f|
        f.request :multipart
        f.response :raise_error
        f.response :json, parser_options: { symbolize_names: true }
        f.adapter Faraday.default_adapter
      end
    end
  end
end
