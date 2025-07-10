# frozen_string_literal: true

module ClaimsEvidenceApi
  # JSON Schema paths
  # @see https://fwdproxy-dev.vfs.va.gov:4463/api/v1/rest/openapi.json
  # @see modules/claims_evidence_api/documentation/claims-evidence-openapi.json
  # voxpupuli/json-schema (gem) only supports up to draft-06
  module JsonSchema
    DIR = "#{__dir__}/schema".freeze

    # #/components/schemas/payload
    UPLOAD_PAYLOAD = "#{DIR}/uploadPayload.json".freeze
    # #/components/schemas/updateDataProviderData
    PROVIDER_DATA = "#{DIR}/providerData.json".freeze

    # end JsonSchema
  end

  # end ClaimsEvidenceApi
end
