# frozen_string_literal: true

class RswagConfig
  def config
    {
      'config/openapi/openapi.json' => {
        openapi: '3.0.3',
        info: info_spec,
        paths: {},
        servers: [],
        components: Openapi::Components::ALL
      }
    }
  end

  private

  def info_spec
    {
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
    }
  end
end
