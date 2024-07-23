# frozen_string_literal: true

module Swagger
  module Requests
    class IncomeAndAssetsClaims
      include Swagger::Blocks

      swagger_path '/v0/form0969' do
        operation :post do
          extend Swagger::Responses::ValidationError
          extend Swagger::Responses::SavedForm

          key :description, 'Submit a income and assets statement'
          key :operationId, 'addIncomeAndAssetsClaim'
          key :tags, %w[benefits_forms]

          parameter :optional_authorization

          parameter do
            key :name, :form
            key :in, :body
            key :description, 'Income and assets statement form data'
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
