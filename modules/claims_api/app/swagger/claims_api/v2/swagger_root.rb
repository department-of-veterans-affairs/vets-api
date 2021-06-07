# frozen_string_literal: true

module ClaimsApi
  module V2
    class SwaggerRoot
      include Swagger::Blocks

      swagger_root do
        key :openapi, '3.0.0'
        info do
          key :version, '2.0.0'
          key :title, 'Benefits Claims'
          key :description, File.read(Rails.root.join('modules', 'claims_api', 'app', 'swagger', 'claims_api', 'description', 'v2.md'))
          key :termsOfService, 'https://developer.va.gov/terms-of-service'
          contact do
            key :name, 'VA API Benefits Team'
          end
          license do
            key :name, 'Creative Commons'
          end
        end

        tag do
          key :name, 'Veteran Identifier'
          key :description, "Allows authenticated veterans and veteran representatives to retrieve a veteran's id."
        end

        tag do
          key :name, 'Claims'
          key :description, 'Allows authenticated and authorized users to access claims data for a given Veteran. No data is returned if the user is not authenticated and authorized.'
        end

        server do
          key :url, 'https://dev-api.va.gov/services/benefits/{version}'
          key :description, 'VA.gov API development environment'
          variable :version do
            key :default, 'v2'
          end
        end

        key :basePath, '/services/benefits/v2'
        key :consumes, ['application/json']
        key :produces, ['application/json']
      end
    end
  end
end
