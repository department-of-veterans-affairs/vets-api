# frozen_string_literal: true

module VaForms
  module V0
    class SwaggerRoot
      include Swagger::Blocks
      swagger_root do
        key :openapi, '3.0.0'
        info do
          key :version, '0.0.0'
          key :title, 'VA Forms'
          key :description, File.read(VaForms::Engine.root.join('app', 'swagger', 'va_forms', 'v0', 'description.md'))
          contact do
            key :name, 'va.gov'
          end
        end

        server do
          key :url, 'https://dev-api.va.gov/services/va_forms/{version}'
          key :description, 'VA.gov API development environment'
          variable :version do
            key :default, 'v0'
          end
        end

        server do
          key :url, 'https://staging-api.va.gov/services/va_forms/{version}'
          key :description, 'VA.gov API staging environment'
          variable :version do
            key :default, 'v0'
          end
        end

        server do
          key :url, 'https://api.va.gov/services/va_forms/{version}'
          key :description, 'VA.gov API production environment'
          variable :version do
            key :default, 'v0'
          end
        end

        key :basePath, '/services/va_forms/v0'
        key :consumes, ['application/json']
        key :produces, ['application/json']
      end
    end
  end
end
