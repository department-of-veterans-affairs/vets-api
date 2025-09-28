# frozen_string_literal: true

module Swagger
  module Requests
    class SurvivorsBenefitsClaims
      include Swagger::Blocks

      swagger_path '/v0/form534ez' do
        operation :post do
          extend Swagger::Responses::ValidationError
          extend Swagger::Responses::SavedForm

          key :description, 'Submit an application for DIC, Survivor\'s Penion, and/or Accrued Benefits'
          key :operationId, 'addSurvivorsBenefitsClaim'
          key :tags, %w[benefits_forms]

          parameter :optional_authorization

          parameter do
            key :name, :form
            key :in, :body
            key :description, 'Survivors\'s benefits claim form data'
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
