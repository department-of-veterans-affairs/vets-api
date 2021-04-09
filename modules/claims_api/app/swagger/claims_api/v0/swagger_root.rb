# frozen_string_literal: true

module ClaimsApi
  module V0
    class SwaggerRoot
      include Swagger::Blocks

      swagger_root do
        key :openapi, '3.0.0'
        info do
          key :version, '0.0.1'
          key :title, 'Benefits Claims'
          key :description, File.read(Rails.root.join('modules', 'claims_api', 'app', 'swagger', 'claims_api', 'description', 'v0.md'))
          key :termsOfService, 'https://developer.va.gov/terms-of-service'
          contact do
            key :name, 'VA API Benefits Team'
          end
          license do
            key :name, 'Creative Commons'
          end
        end
        tag do
          key :name, 'Claims'
          key :description, 'Allows authenticated and authorized users to access claims data for a single claim by ID, or for all claims based on Veteran data. No data is returned if the user is not authenticated and authorized.'
        end

        tag do
          key :name, 'Disability'
          key :description, 'Used for 526 claims.'
        end

        tag do
          key :name, 'Intent to File'
          key :description, 'Used for 0966 submissions.'
        end

        tag do
          key :name, 'Power of Attorney'
          key :description, 'Used for 21-22 and 21-22a form submissions.'
        end

        server do
          key :url, 'https://sandbox-api.va.gov/services/claims/{version}'
          key :description, 'VA.gov API sandbox environment'
          variable :version do
            key :default, 'v0'
          end
        end

        server do
          key :url, 'https://api.va.gov/services/claims/{version}'
          key :description, 'VA.gov API production environment'
          variable :version do
            key :default, 'v0'
          end
        end

        key :basePath, '/services/claims/v0'
        key :consumes, ['application/json']
        key :produces, ['application/json']
      end
    end
  end
end
