# frozen_string_literal: true

require 'claims_evidence_api/engine'

# Claims Evidence API
# https://claimevidence-api-test.dev.bip.va.gov/api/v1/rest/swagger-ui.html
module ClaimsEvidenceApi
  # The module path
  MODULE_PATH = 'modules/claims_evidence_api'

  # Collection of module exceptions
  module Exceptions; end

  # JSON Schema paths
  # @see https://fwdproxy-dev.vfs.va.gov:4463/api/v1/rest/openapi.json
  # @see modules/claims_evidence_api/documentation/claims-evidence-openapi.json
  # voxpupuli/json-schema (gem) only supports up to draft-06
  module JsonSchema; end

  # Proxy Service for the ClaimsEvidence API
  # @see https://depo-platform-documentation.scrollhelp.site/developer-docs/endpoint-monitoring
  # @see https://fwdproxy-dev.vfs.va.gov:4463/api/v1/rest/swagger-ui.html
  module Service; end

  # Validations to be used with ClaimsEvidence API requests
  module Validation; end
end
