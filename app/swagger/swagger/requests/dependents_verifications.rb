# frozen_string_literal: true

module Swagger
  module Requests
    class DependentsVerifications
      include Swagger::Blocks

      swagger_path '/v0/dependents_verifications' do
        operation :get do
          extend Swagger::Responses::AuthenticationError

          key :description, "Get the veteran's dependent status"
          key :operationId, 'getDependentsVerifications'
          key :tags, %w[dependents_verifications]

          parameter :authorization

          response 200 do
            key :description, 'Response is OK'
            schema do
              key :$ref, :DependentsVerifications
            end
          end
        end
      end
    end
  end
end
