# frozen_string_literal: true

require 'claims_evidence_api/service/base'

module ClaimsEvidenceApi
  module Service
    # Files API
    class Files < Base
      # POST upload/create a file to a vbms folder
      # @see https://fwdproxy-dev.vfs.va.gov:4463/api/v1/rest/swagger-ui.html#/File/upload
      #
      # @param file_path [String] the path to the file to upload
      # @param provider_data [Hash] metadata to be associated with the file
      def upload(file_path, provider_data:)
        raise UndefinedXFolderURI unless x_folder_uri

        validate_folder_identifier(x_folder_uri)

        headers = { 'X-Folder-URI' => x_folder_uri }
        params = post_params(file_path, provider_data)

        perform :post, 'files', params, headers
      end
      alias create upload

      # GET retrieve file data
      # @see https://fwdproxy-dev.vfs.va.gov:4463/api/v1/rest/swagger-ui.html#/File/getData
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
      # @see https://fwdproxy-dev.vfs.va.gov:4463/api/v1/rest/swagger-ui.html#/File/updateData
      #
      # @param uuid [String] The UUID of the file data
      # @param provider_data [Hash] metadata to be associated with the file
      def update(uuid, provider_data: {})
        provider_data = validate_provider_data(provider_data)
        perform :put, "files/#{uuid}/data", provider_data
      end

      # POST overwrite a file in a vbms folder, but retain the uuid
      # @see https://fwdproxy-dev.vfs.va.gov:4463/api/v1/rest/swagger-ui.html#/File/update
      #
      # @param file_path [String] the path to the file to upload
      # @param provider_data [Hash] metadata to be associated with the file
      def overwrite(uuid, file_path, provider_data:)
        raise UndefinedXFolderURI unless x_folder_uri

        validate_folder_identifier(x_folder_uri)

        headers = { 'X-Folder-URI' => x_folder_uri }
        params = post_params(file_path, provider_data)

        perform :post, "files/#{uuid}", params, headers
      end

      private

      # construct the body for POST requests
      #
      # @param file_path [String] the path to the file to upload
      # @param provider_data [Hash] metadata to be associated with the file
      def post_params(file_path, provider_data)
        raise FileNotFound unless File.exist?(file_path)

        file_name = File.basename(file_path)
        mime_type = Marcel::MimeType.for(file_path)

        {
          payload: validate_upload_payload(file_name, provider_data),
          file: Faraday::UploadIO.new(file_path, mime_type, file_name)
        }
      end

      # end Files
    end

    # end Service
  end

  # end ClaimsEvidenceApi
end
