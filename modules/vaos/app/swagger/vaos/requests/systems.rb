# frozen_string_literal: true

module VAOS
  module Requests
    class Systems
      include Swagger::Blocks

      swagger_path '/systems' do
        operation :get do
          extend Swagger::Responses::AuthenticationError

          key :description, 'returns list of system identifiers for a user'
          key :operationId, 'getSystems'
          key :tags, %w[systems]

          parameter :authorization

          response 200 do
            key :description,
                'The list of systems the user is registered in'
            schema do
              key :'$ref', :Systems
            end
          end

          response 401 do
            key :description, 'User is not authenticated (logged in)'
            schema do
              key :'$ref', :Errors
            end
          end

          response 403 do
            key :description, 'Forbidden: user is not authorized for VAOS'
            schema do
              key :'$ref', :Errors
            end
          end

          response 502 do
            key :description, 'Bad Gateway: the upstream VAOS service returned an invalid response (500+)'
            schema do
              key :'$ref', :Errors
            end
          end
        end
      end
    end
  end
end
