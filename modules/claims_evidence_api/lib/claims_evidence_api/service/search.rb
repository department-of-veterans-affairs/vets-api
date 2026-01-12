# frozen_string_literal: true

require 'claims_evidence_api/service/base'

module ClaimsEvidenceApi
  module Service
    # Search API
    # @see https://fwdproxy-prod.vfs.va.gov:4469/api/v1/rest/swagger-ui.html#/Folder/searchFiles
    class Search < Base
      # POST find a list of documents matching filter criteria in a folder_identifier
      # @see https://fwdproxy-prod.vfs.va.gov:4469/api/v1/rest/swagger-ui.html#/Folder/searchFiles
      # @see ClaimsEvidenceApi::Validation::SearchFileRequest
      #
      # @param results_per_page [Integer] number of results per page; default = 10
      # @param page [Integer] page to begin returning results; default = 1
      # @param filters [Hash] filters to be applied to the search; filterId-args
      # @param sort [Hash] sort to apply to the results; filterId-direction
      # @param transform [Array<Symbol>] if the filters|sort should be formatted to match the schema
      def find(results_per_page: 10, page: 1, filters: {}, sort: {}, transform: %i[filters sort])
        raise UndefinedXFolderURI unless folder_identifier

        validate_folder_identifier(folder_identifier)

        validation = ClaimsEvidenceApi::Validation::SearchFileRequest
        filters = validation::Filters.transform(filters) if transform.include?(:filters)
        sort = validation::Sort.transform(sort) if transform.include?(:sort)

        headers = { 'X-Folder-URI' => folder_identifier }
        request = validate_search_file_request(results_per_page:, page:, filters:, sort:)

        perform :post, 'folders/files:search', request, headers
      end

      private

      # @see ClaimsEvidenceApi::Service::Base#endpoint
      def endpoint
        'search'
      end

      # end Search
    end

    # end Service
  end

  # end ClaimsEvidenceApi
end
