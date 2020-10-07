# frozen_string_literal: true

module ClaimsApi
  module V1
    class SwaggerRoot
      include Swagger::Blocks

      swagger_root do
        key :openapi, '3.0.0'
        info do
          key :version, '1.0.0'
          key :title, 'Benefits Claims'
          key :description, File.read(Rails.root.join('modules', 'claims_api', 'app', 'swagger', 'claims_api', 'description', 'v1.md'))
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
          key :description, 'Benefits Claims'
        end

        tag do
          key :name, 'Disability'
          key :description, '526 Claim Submissions'
        end

        tag do
          key :name, 'Intent to File'
          key :description, '0966 Submissions'
        end

        tag do
          key :name, 'Power of Attorney'
          key :description, '2122 Submissions'
        end

        server do
          key :url, 'https://sandbox-api.va.gov/services/claims/{version}'
          key :description, 'VA.gov API sandbox environment'
          variable :version do
            key :default, 'v1'
          end
        end

        server do
          key :url, 'https://api.va.gov/services/claims/{version}'
          key :description, 'VA.gov API production environment'
          variable :version do
            key :default, 'v1'
          end
        end

        key :basePath, '/services/claims/v1'
        key :consumes, ['application/json']
        key :produces, ['application/json']
      end
    end
  end
end
