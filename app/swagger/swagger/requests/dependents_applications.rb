# frozen_string_literal: true

module Swagger
  module Requests
    class DependentsApplications
      include Swagger::Blocks

      swagger_path '/v0/dependents_applications/show' do
        operation :get do
          extend Swagger::Responses::AuthenticationError

          key :description, 'Get the dependents for a veteran by participant ID'
          key :operationId, 'getDependents'
          key :tags, %w[dependents_applications]

          parameter :authorization

          response 200 do
            key :description, 'Response is OK'
            schema do
              key :$ref, :Dependents
            end
          end
        end
      end

      swagger_path '/v0/dependents_applications' do
        operation :post do
          extend Swagger::Responses::ValidationError
          extend Swagger::Responses::SavedForm

          key :description, 'Submit a dependency claim'
          key :operationId, 'addDependencyClaim'
          key :tags, %w[benefits_forms]

          parameter :optional_authorization

          parameter do
            key :name, :form
            key :in, :body
            key :description, 'Dependency claim form data'
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
