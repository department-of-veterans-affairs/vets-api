# frozen_string_literal: true

module Swagger
  module Requests
    class PensionClaims
      include Swagger::Blocks

      a = 1
      b = 2
      c = 3

      swagger_path 'pensions/v0/pension_claims' do
        operation :post do
          extend Swagger::Responses::ValidationError
          extend Swagger::Responses::SavedForm

          key :operationId, 'addPensionClaim'
          key :tags, %w[benefits_forms]

          parameter :optional_authorization

          parameter do
            key :name, :form
            key :in, :body
            key :description, 'Pension claim form data'
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
