# frozen_string_literal: true

module Swagger
  module Requests
    class Appeals
      include Swagger::Blocks

      swagger_path '/v0/appeals_v2' do
        operation :get do
          extend Swagger::Responses::AuthenticationError

          key :description, 'returns list of appeals for a user'
          key :operationId, 'getAppeals'
          key :tags, %w[
            appeals
          ]

          parameter :authorization

          response 200 do
            key :description,
                '200 passes the response from the upstream appeals API. Their swagger can be viewed here https://app.swaggerhub.com/apis/dsva-appeals/appeals-status/2.0.0#/default/appeals'
            schema do
              key :'$ref', :Appeals
            end
          end

          response 401 do
            key :description, 'User is not authenticated (logged in)'
            schema do
              key :'$ref', :Errors
            end
          end

          response 403 do
            key :description, 'Forbidden: user is not authorized for appeals'
            schema do
              key :'$ref', :Errors
            end
          end

          response 404 do
            key :description, 'Not found: appeals not found for user'
            schema do
              key :'$ref', :Errors
            end
          end

          response 422 do
            key :description, 'Unprocessable Entity: one or more validations has failed'
            schema do
              key :'$ref', :Errors
            end
          end

          response 502 do
            key :description, 'Bad Gateway: the upstream appeals app returned an invalid response (500+)'
            schema do
              key :'$ref', :Errors
            end
          end
        end
      end
    end
  end
end
