# frozen_string_literal: true

class OpenAPIRswagConfig
  def config
    {
      'public/openapi.json' => {
        openapi: '3.0.3',
        info: {
          title: 'OpenAPI Docs',
          version: '1.0'
        },
        paths: {},
        servers: []
      }
    }
  end
end
