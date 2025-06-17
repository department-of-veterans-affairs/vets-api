# frozen_string_literal: true

module Swagger
  module Requests
    class DependentsVerificationClaims
      include Swagger::Blocks

      swagger_path '/v0/form0538' do
        operation :post do
          extend Swagger::Responses::ValidationError
          extend Swagger::Responses::SavedForm

          key :description, 'Submit a dependents verification'
          key :operationId, 'addDependentsVerificationClaim'
          key :tags, %w[benefits_forms]

          parameter :optional_authorization

          parameter do
            key :name, :form
            key :in, :body
            key :description, 'Dependents Verification form data'
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
