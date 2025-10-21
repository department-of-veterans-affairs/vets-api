# frozen_string_literal: true

class RswagConfig
  def config
    {
      'public/openapi.json' => {
        openapi: '3.0.3',
        info: {
          title: 'VA.gov OpenAPI Docs',
          version: '1.0',
          description: 'OpenAPI 3.0.3 Documentation for the VA.gov API',
          contact: {
            name: 'https://developer.va.gov/support/contact-us'
          },
          license: {
            name: 'Creative Commons Zero v1.0 Universal'
          }
        },
        paths: {},
        servers: []
      }
    }
  end
end
