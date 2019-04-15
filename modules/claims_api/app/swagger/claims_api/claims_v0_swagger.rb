# frozen_string_literal: true

module ClaimsApi
  class ClaimsV0Swagger
    include Swagger::Blocks

    swagger_root do
      key :swagger, '2.0'
      info do
        key :version, '0.0.1'
        key :title, 'Benefits Claims'
        key :description, File.read(Rails.root.join('modules/claims_api/app/swagger/claims_api', 'description.md'))
        key :termsOfService, 'https://developer.va.gov/terms-of-service'
        contact do
          key :name, 'VA API Benefits Team'
        end
        license do
          key :name, 'Creative Commons'
        end
      end
      tag do
        key :name, 'claims'
        key :description, 'Benefits Claims'
        externalDocs do
          key :description, 'Find more info here'
          key :url, 'https://developer.va.gov'
        end
      end
      key :host, 'api.va.gov'
      key :basePath, '/services/claims/v1'
      key :consumes, ['application/json']
      key :produces, ['application/json']
    end
  end
end
