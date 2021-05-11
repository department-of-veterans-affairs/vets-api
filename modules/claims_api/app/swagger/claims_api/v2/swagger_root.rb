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
          key :description, "Allows authenticated veteran's and veteran representatives to retrieve a veteran's ICN."
        end

        server do
          key :url, 'https://sandbox-api.va.gov/services/claims/{version}'
          key :description, 'VA.gov API sandbox environment'
          variable :version do
            key :default, 'v2'
          end
        end

        server do
          key :url, 'https://api.va.gov/services/claims/{version}'
          key :description, 'VA.gov API production environment'
          variable :version do
            key :default, 'v2'
          end
        end

        key :basePath, '/services/claims/v2'
        key :consumes, ['application/json']
        key :produces, ['application/json']
      end
    end
  end
end
