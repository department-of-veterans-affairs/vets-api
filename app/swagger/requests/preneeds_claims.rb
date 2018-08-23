# frozen_string_literal: true

module Swagger
  module Requests
    class PreneedsClaims
      include Swagger::Blocks

      swagger_path '/v0/preneeds/burial_forms' do
        operation :post do
          extend Swagger::Responses::ValidationError
          extend Swagger::Responses::SavedForm

          key :description, 'Submit a pre-need burial eligibility claim'
          key :operationId, 'addPreneedsClaim'
          key :tags, %w[benefits_forms]

          parameter :optional_authorization

          parameter do
            key :name, :form
            key :in, :body
            key :description, 'Pre-need burial eligibility form data'
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
