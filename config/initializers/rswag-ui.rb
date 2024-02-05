# frozen_string_literal: true

Rswag::Ui.configure do |c|
  c.openapi_endpoint '/services/claims/docs/v1/api', 'Claims API V1 Docs'
  c.openapi_endpoint('/services/claims/docs/v2/api', 'Claims API V2 Docs') if Settings.claims_api.v2_docs.enabled
end
