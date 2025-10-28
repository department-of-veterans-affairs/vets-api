# frozen_string_literal: true

module Swagger
  module Requests
    class IncreaseCompensationClaims
      include Swagger::Blocks

      swagger_path '/v0/form8940' do
        operation :post do
          extend Swagger::Responses::ValidationError
          extend Swagger::Responses::SavedForm

          key :description, 'Submit a request to increase compensation'
          key :operationId, 'addIncreaseCompensationClaim'
          key :tags, %w[benefits_forms]

          parameter :optional_authorization

          parameter do
            key :name, :form
            key :in, :body
            key :description, 'Increase compensation form data'
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
