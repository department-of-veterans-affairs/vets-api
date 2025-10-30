# frozen_string_literal: true

require 'claims_evidence_api/service/base'

module ClaimsEvidenceApi
  module Service
    # Search API
    # @see https://fwdproxy-prod.vfs.va.gov:4469/api/v1/rest/swagger-ui.html#/Folder/searchFiles
    class Search < Base
      def find(page: 1, results_per_page: 10, filters: {}, sort: {}, transform_filters: true)
        raise UndefinedXFolderURI unless folder_identifier

        validate_folder_identifier(folder_identifier)

        filters = ClaimsEvidenceApi::Validation::SearchFilters.transform(filters) if transform_filters

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
