# frozen_string_literal: true

require 'claims_evidence_api/service/base'
require 'common/virus_scan'

module ClaimsEvidenceApi
  module Service
    # Search API
    # @see https://fwdproxy-prod.vfs.va.gov:4469/api/v1/rest/swagger-ui.html#/Folder/searchFiles
    class Search < Base
      def find(page: 1, results_per_page: 10, filters: {}, sort: {})
        raise UndefinedXFolderURI unless folder_identifier

        validate_folder_identifier(folder_identifier)

        headers = { 'X-Folder-URI' => folder_identifier }

        request = validate_search_file_request(page, results_per_page, filters, sort)

        perform :post, "folders/files:search", request, headers
      end

      private

      # @see ClaimsEvidenceApi::Service::Base#endpoint
      def endpoint
        'search'
      end

      # end Files
    end

    # end Service
  end

  # end ClaimsEvidenceApi
end
