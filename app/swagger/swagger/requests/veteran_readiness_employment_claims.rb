# frozen_string_literal: true

module Swagger
  module Requests
    class VeteranReadinessEmploymentClaims
      include Swagger::Blocks

      swagger_path '/v0/veteran_readiness_employment_claims' do
        operation :post do
          extend Swagger::Responses::ValidationError
          extend Swagger::Responses::SavedForm

          key :description, 'Submit an employment readiness claim (CH31)/28-1900'
          key :operationId, 'adVeteranReadinessEmploymentClaim'
          key :tags, %w[benefits_forms]

          parameter :optional_authorization

          parameter do
            key :name, :form
            key :in, :body
            key :description, 'Veteran Readiness Employment Claim form data'
            key :required, true

            schema do
              key :type, :string
            end
          end
        end
      end
    end
  end
end
