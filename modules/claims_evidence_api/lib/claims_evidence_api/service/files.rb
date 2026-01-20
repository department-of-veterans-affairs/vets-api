# frozen_string_literal: true

require 'claims_evidence_api/service/base'
require 'common/virus_scan'

module ClaimsEvidenceApi
  module Service
    # Files API
    # @see https://fwdproxy-prod.vfs.va.gov:4469/api/v1/rest/swagger-ui.html#/File
    class Files < Base
      # POST upload/create a file to a vbms folder
      # @see https://fwdproxy-prod.vfs.va.gov:4469/api/v1/rest/swagger-ui.html#/File/upload
      #
      # @param file_path [String] the path to the file to upload
      # @param provider_data [Hash] metadata to be associated with the file
      def upload(file_path, provider_data:)
        raise UndefinedXFolderURI unless folder_identifier

        validate_folder_identifier(folder_identifier)

        headers = { 'X-Folder-URI' => folder_identifier, 'Content-Type' => 'multipart/form-data' }
        params = post_params(file_path, provider_data)

        perform :post, 'files', params, headers
      end
      alias create upload

      # GET retrieve file data
      # @see https://fwdproxy-prod.vfs.va.gov:4469/api/v1/rest/swagger-ui.html#/File/getData
      #
      # @param uuid [String] The UUID of the file data
      # @param include_raw_text [Boolean] optional param to include raw text data of the document; default: false
      def retrieve(uuid, include_raw_text: false)
        # cast the optional argument to an actual boolean value
        include_raw_text = !!include_raw_text # rubocop:disable Style/DoubleNegation

        perform :get, "files/#{uuid}/data?includeRawTextData=#{include_raw_text}", {}
      end
      alias read retrieve

      # PUT update file data for a specific UUID
      # @see https://fwdproxy-prod.vfs.va.gov:4469/api/v1/rest/swagger-ui.html#/File/updateData
      #
      # @param uuid [String] The UUID of the file data
      # @param provider_data [Hash] metadata to be associated with the file
      def update(uuid, provider_data: {})
        provider_data = validate_provider_data(provider_data)
        perform :put, "files/#{uuid}/data", provider_data
      end

      # POST overwrite a file in a vbms folder, but retain the uuid
      # @see https://fwdproxy-prod.vfs.va.gov:4469/api/v1/rest/swagger-ui.html#/File/update
      #
      # @param uuid [String] The UUID of the file data
      # @param file_path [String] the path to the file to upload
      # @param provider_data [Hash] metadata to be associated with the file
      def overwrite(uuid, file_path, provider_data:)
        raise UndefinedXFolderURI unless folder_identifier

        validate_folder_identifier(folder_identifier)

        headers = { 'X-Folder-URI' => folder_identifier }
        params = post_params(file_path, provider_data)

        perform :post, "files/#{uuid}", params, headers
      end

      # GET retrieve the associated period of service record to from a document
      # @see https://fwdproxy-prod.vfs.va.gov:4469/api/v1/rest/swagger-ui.html#/Period%20Of%20Service
      #
      # only certain documents will have associated period of service records
      #
      # @param uuid [String] The UUID of the file data
      def period_of_service(uuid)
        perform :get, "files/#{uuid}/periodOfService", {}
      end

      # GET file content for a given version as a pdf
      # @see https://fwdproxy-prod.vfs.va.gov:4469/api/v1/rest/swagger-ui.html#/Version%20Content
      #
      # @param uuid [String] The UUID of the file data
      # @param version [String] version UUID of the file data
      def download(uuid, version)
        headers = { 'Accept' => 'application/pdf' }
        perform :get, "files/#{uuid}/#{version}/content", {}, headers
      end

      private

      # @see ClaimsEvidenceApi::Service::Base#endpoint
      def endpoint
        'files'
      end

      # construct the body for POST requests
      #
      # @param file_path [String] the path to the file to upload
      # @param provider_data [Hash] metadata to be associated with the file
      def post_params(file_path, provider_data)
        raise FileNotFound, file_path unless File.exist?(file_path)
        raise VirusFound, file_path unless Common::VirusScan.scan(file_path)

        file_name = File.basename(file_path)
        mime_type = Marcel::MimeType.for(file_path)
        payload = validate_upload_payload(file_name, provider_data)

        {
          payload: payload&.to_json,
          file: Faraday::UploadIO.new(file_path, mime_type, file_name)
        }
      end

      # end Files
    end

    # end Service
  end

  # end ClaimsEvidenceApi
end
