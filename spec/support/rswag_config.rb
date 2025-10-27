# frozen_string_literal: true

require 'rswag/v0/shared_schemas/errors'
require 'rswag/v0/shared_schemas/form212680'

class RswagConfig
  # rubocop:disable Metrics/MethodLength
  def config
    {
      'public/openapi.json' => {
        openapi: '3.0.3',
        info: {
          title: 'VA.gov OpenAPI Docs',
          version: '1.0',
          description: 'OpenAPI 3.0.3 Documentation for the VA.gov API',
          contact: {
            name: 'VA Platform Support',
            url: 'https://depo-platform-documentation.scrollhelp.site/support/'
          },
          license: {
            name: 'Creative Commons Zero v1.0 Universal'
          }
        },
        paths: {},
        servers: [],
        components: {
          schemas: {
            Errors: Rswag::V0::SharedSchemas::Errors::ERRORS,
            Error: Rswag::V0::SharedSchemas::Errors::ERROR,
            Form212680FullName: Rswag::V0::SharedSchemas::Form212680::FORM_212680_FULL_NAME,
            Form212680Address: Rswag::V0::SharedSchemas::Form212680::FORM_212680_ADDRESS
          }

        }
      }
    }
  end
  # rubocop:enable Metrics/MethodLength
end
