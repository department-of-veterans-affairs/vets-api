# frozen_string_literal: true

module Swagger
  module Requests
    class BurialClaims
      include Swagger::Blocks

      swagger_path '/burials/v0/claims' do
        operation :post do
          extend Swagger::Responses::ValidationError
          extend Swagger::Responses::SavedForm

          key :description, 'Submit a burial benefit claim'
          key :operationId, 'addBurialClaim'
          key :tags, %w[benefits_forms]

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
