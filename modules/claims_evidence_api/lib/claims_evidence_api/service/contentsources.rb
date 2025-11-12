# frozen_string_literal: true

require 'claims_evidence_api/service/base'

module ClaimsEvidenceApi
  module Service
    # ContentSources API
    # @see https://fwdproxy-prod.vfs.va.gov:4469/api/v1/rest/swagger-ui.html#/Content%20Sources
    class ContentSources < Base
      # GET retrieve the list of content sources
      # @see https://fwdproxy-prod.vfs.va.gov:4469/api/v1/rest/swagger-ui.html#/Content%20Sources/getContentSources
      def retrieve
        raise UndefinedXFolderURI unless folder_identifier

        validate_folder_identifier(folder_identifier)

        headers = { 'X-Folder-URI' => folder_identifier }

        perform :get, 'contentsources', {}, headers
      end

      private

      # @see ClaimsEvidenceApi::Service::Base#endpoint
      def endpoint
        'contentsources'
      end

      # end ContentSources
    end

    # end Service
  end

  # end ClaimsEvidenceApi
end
