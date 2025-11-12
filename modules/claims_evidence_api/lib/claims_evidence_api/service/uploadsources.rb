# frozen_string_literal: true

require 'claims_evidence_api/service/base'

module ClaimsEvidenceApi
  module Service
    # UploadSources API
    # @see https://fwdproxy-prod.vfs.va.gov:4469/api/v1/rest/swagger-ui.html#/Upload%20Sources
    class UploadSources < Base
      # GET retrieve the list of upload sources
      # @see https://fwdproxy-prod.vfs.va.gov:4469/api/v1/rest/swagger-ui.html#/Upload%20Sources/getUploadSources
      def retrieve
        raise UndefinedXFolderURI unless folder_identifier

        validate_folder_identifier(folder_identifier)

        headers = { 'X-Folder-URI' => folder_identifier }

        perform :get, 'folders/uploadsources', {}, headers
      end

      private

      # @see ClaimsEvidenceApi::Service::Base#endpoint
      def endpoint
        'uploadsources'
      end

      # end UploadSources
    end

    # end Service
  end

  # end ClaimsEvidenceApi
end
