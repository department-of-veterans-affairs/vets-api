# frozen_string_literal: true

module AppsApi
  module V0
    class SwaggerRoot
      include Swagger::Blocks
      swagger_root do
        key :openapi, '3.0.0'
        info do
          key :version, '0.0.0'
          key :title, 'Apps Api'
          key :description, File.read(AppsApi::Engine.root.join('app', 'swagger', 'apps_api', 'v0', 'description.md'))
          contact do
            key :name, 'va.gov'
          end
        end

        server do
          key :url, 'https://sandbox-api.va.gov/services/apps/{version}'
          key :description, 'VA.gov API sandbox environment'
          variable :version do
            key :default, 'v0'
          end
        end

        server do
          key :url, 'https://api.va.gov/services/apps/{version}'
          key :description, 'VA.gov API production environment'
          variable :version do
            key :default, 'v0'
          end
        end

        key :basePath, '/services/apps/v0'
        key :consumes, ['application/json']
        key :produces, ['application/json']
      end
    end
  end
end
