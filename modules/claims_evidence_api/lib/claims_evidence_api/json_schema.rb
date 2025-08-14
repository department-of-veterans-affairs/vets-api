# frozen_string_literal: true

module ClaimsEvidenceApi
  module JsonSchema
    # base path for our schemas
    DIR = "#{__dir__}/schema".freeze

    # #/components/schemas/payload
    UPLOAD_PAYLOAD = "#{DIR}/uploadPayload.json".freeze
    # #/components/schemas/updateDataProviderData
    PROVIDER_DATA = "#{DIR}/providerData.json".freeze

    # end JsonSchema
  end

  # end ClaimsEvidenceApi
end
