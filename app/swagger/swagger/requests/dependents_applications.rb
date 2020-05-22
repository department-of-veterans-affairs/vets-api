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
              key :'$ref', :Dependents
            end
          end
        end
      end
    end
  end
end
