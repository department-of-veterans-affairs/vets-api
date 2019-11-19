# frozen_string_literal: true

module VaForms
  module V0
    class SwaggerRoot
      include Swagger::Blocks
      swagger_root do
        key :swagger, '2.0'
        info do
          key :version, '0.0.0'
          key :title, 'VA Forms'
          key :description, File.read(VaForms::Engine.root.join('app', 'swagger', 'va_forms', 'v0', 'description.md'))
          contact do
            key :name, 'va.gov'
          end
        end

        tag do
          key :name, 'va_forms'
          key :description, 'VA Form information API'
          externalDocs do
            key :description, 'Find more info here'
            key :url, 'https://developer.va.gov'
          end
        end

        key :servers, [
          {
            "url": 'https://dev-api.va.gov/services/va_forms/{version}',
            "description": 'VA.gov API development environment',
            "variables": {
              "version": {
                "default": 'v0'
              }
            }
          },
          {
            "url": 'https://staging-api.va.gov/services/va_forms/{version}',
            "description": 'VA.gov API staging environment',
            "variables": {
              "version": {
                "default": 'v0'
              }
            }
          },
          {
            "url": 'https://api.va.gov/services/va_forms/{version}',
            "description": 'VA.gov API production environment',
            "variables": {
              "version": {
                "default": 'v0'
              }
            }
          }
        ]

        security_definition :apikey do
          key :type, :apiKey
          key :name, :apikey
          key :in, :header
        end

        key :schemes, ['https']
        key :host, 'api.va.gov'
        key :basePath, '/services/va_forms/v0'
        key :consumes, ['application/json']
        key :produces, ['application/json']
      end
    end
  end
end
