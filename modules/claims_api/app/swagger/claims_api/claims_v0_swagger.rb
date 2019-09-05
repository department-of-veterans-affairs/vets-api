# frozen_string_literal: true

module ClaimsApi
  class ClaimsV0Swagger
    include Swagger::Blocks

    swagger_root do
      key :swagger, '2.0'
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
        key :description, 'Benefits Claims'
        externalDocs do
          key :description, 'Find more info here'
          key :url, 'https://developer.va.gov'
        end
      end

      tag do
        key :name, 'Disability'
        key :description, '526 Claim Submissions'
        externalDocs do
          key :description, 'Find more info here'
          key :url, 'https://developer.va.gov'
        end
      end

      tag do
        key :name, 'Intent to File'
        key :description, '0966 Submissions'
        externalDocs do
          key :description, 'Find more info here'
          key :url, 'https://developer.va.gov'
        end
      end

      key :servers, [
        {
          "url": 'https://dev-api.va.gov/services/claims/{version}',
          "description": 'VA.gov API development environment',
          "variables": {
            "version": {
              "default": 'v0'
            }
          }
        },
        {
          "url": 'https://staging-api.va.gov/services/claims/{version}',
          "description": 'VA.gov API staging environment',
          "variables": {
            "version": {
              "default": 'v0'
            }
          }
        },
        {
          "url": 'https://api.va.gov/services/claims/{version}',
          "description": 'VA.gov API production environment',
          "variables": {
            "version": {
              "default": 'v0'
            }
          }
        }
      ]

      key :components,
          "securitySchemes": {
            "api_key": {
              "type": 'apiKey',
              "in": 'header',
              "name": 'X-API-Key'
            }
          }

      key :host, 'api.va.gov'
      key :basePath, '/services/claims/v0'
      key :consumes, ['application/json']
      key :produces, ['application/json']
    end
  end
end
