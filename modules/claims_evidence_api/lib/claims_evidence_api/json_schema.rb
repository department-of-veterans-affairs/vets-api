# frozen_string_literal: true

module ClaimsEvidenceApi
  module JsonSchema
    # base path for our schemas
    SCHEMA = "#{__dir__}/schema".freeze

    class << self
      private

      # assemble the leaf node properties available
      def properties
        props = "#{SCHEMA}/properties"
        props = Dir.children(props).map { |f| "#{props}/#{f}" }.select { |f| File.file?(f) }
        props.index_by { |prop| File.basename(prop, '.json').to_sym }
      end
    end

    # #/components/schemas/payload
    UPLOAD_PAYLOAD = "#{SCHEMA}/uploadPayload.json".freeze
    # #/components/schemas/updateDataProviderData
    PROVIDER_DATA = "#{SCHEMA}/providerData.json".freeze
    # #/components/schemas/searchFileRequest
    SEARCH_FILE_REQUEST = "#{SCHEMA}/searchFileRequest.json".freeze
    # #/components/schemas/Filters
    SEARCH_FILE_FILTERS = "#{SCHEMA}/searchFileFilters.json".freeze
    # #/components/schemas/Sort
    SEARCH_FILE_SORT = "#{SCHEMA}/searchFileSort.json".freeze

    # hash { :property_name => json-schema }
    # :property_name == filename without extension
    PROPERTIES = properties.freeze

    # end JsonSchema
  end

  # end ClaimsEvidenceApi
end
