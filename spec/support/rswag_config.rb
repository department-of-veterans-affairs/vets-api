# frozen_string_literal: true

class RswagConfig
  def config
    {
      'public/openapi.json' => {
        openapi: '3.0.3',
        info: info_spec,
        paths: {},
        servers: [],
        components: components_spec
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

  def components_spec
    {
      schemas: {
        Errors: Openapi::Schemas::Errors::ERRORS,
        Error: Openapi::Schemas::Errors::ERROR,
        FirstMiddleLastName: Openapi::Schemas::Name::FIRST_MIDDLE_LAST,
        SimpleAddress: Openapi::Schemas::Address::SIMPLE_ADDRESS
      }
    }
  end
end
