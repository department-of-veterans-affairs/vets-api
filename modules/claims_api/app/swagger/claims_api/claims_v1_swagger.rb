# frozen_string_literal: true

module ClaimsApi
  class ClaimsV1Swagger
    include Swagger::Blocks

    swagger_root do
      key :swagger, '2.0'
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

      tag do
        key :name, 'Power of Attorney'
        key :description, '2122 Submissions'
        externalDocs do
          key :description, 'Find more info here'
          key :url, 'https://developer.va.gov'
        end
      end

      security_definition :bearer_token do
        key :type, :apiKey
        key :name, :Authorization
        key :in, :header
      end

      key :schemes, ['https']

      key :host, 'api.va.gov'
      key :basePath, '/services/claims/v1'
      key :consumes, ['application/json']
      key :produces, ['application/json']
    end
  end
end
