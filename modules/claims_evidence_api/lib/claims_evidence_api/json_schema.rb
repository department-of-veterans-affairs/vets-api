# frozen_string_literal: true

module ClaimsEvidenceApi
  module JsonSchema
    # base path for our schemas
    DIR = "#{__dir__}/schema".freeze

    # #/components/schemas/payload
    UPLOAD_PAYLOAD = "#{DIR}/uploadPayload.json".freeze
    # #/components/schemas/updateDataProviderData
    PROVIDER_DATA = "#{DIR}/providerData.json".freeze

    class << self
      private

      # assemble the leaf node properties that can be validated
      def properties
        props = "#{DIR}/properties"
        props = Dir.children(props).map { |f| "#{props}/#{f}" }.select { |f| File.file?(f) }
        props.index_by { |prop| File.basename(prop, '.json').to_sym }
      end
    end

    # hash { :property_name => json-schema }
    # :property_name == filename without extension
    PROPERTIES = properties.freeze

    # end JsonSchema
  end

  # end ClaimsEvidenceApi
end
