# frozen_string_literal: true

# For configuration options, see:
# https://github.com/rswag/rswag/blob/master/README.md#customizing-the-swagger-ui
# https://swagger.io/docs/open-source-tools/swagger-ui/usage/configuration/

Rswag::Ui.configure do |c|
  c.openapi_endpoint '/services/claims/docs/v1/api', 'Claims API V1 Docs'
  c.openapi_endpoint('/services/claims/docs/v2/api', 'Claims API V2 Docs') if Settings.claims_api.v2_docs.enabled
  c.openapi_endpoint '/v0/openapi', 'VA.gov OpenAPI Docs (v3)'
  c.openapi_endpoint '/v0/apidocs', 'VA.gov Swagger Docs (v2)'
  c.config_object['deepLinking'] = true
end
