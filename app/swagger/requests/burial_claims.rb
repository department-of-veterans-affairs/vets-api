# frozen_string_literal: true

module Swagger
  module Requests
    class BurialClaims
      include Swagger::Blocks

      swagger_path '/v0/burial_claims' do
        operation :post do
          extend Swagger::Responses::ValidationError
          extend Swagger::Responses::SavedForm

          key :description, 'Submit a burial benefit claim'
          key :operationId, 'addBurialClaim'
          key :tags, %w[
            burial
            forms
          ]

          parameter :optional_authorization

          parameter do
            key :name, :form
            key :in, :body
            key :description, 'Burial claim form data'
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
