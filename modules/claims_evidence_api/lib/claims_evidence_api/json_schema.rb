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

      def properties
        props = "#{DIR}/properties"
        props = Dir.children(props).map { |f| "#{props}/#{f}" }.select { |f| File.file?(f) }
        props.each_with_object({}) { |prop, hash| hash[File.basename(prop, '.json').to_sym] = prop }
      end
    end

    PROPERTIES = self.properties.freeze

    # end JsonSchema
  end

  # end ClaimsEvidenceApi
end
