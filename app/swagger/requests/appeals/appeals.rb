# frozen_string_literal: true

module Swagger
  module Requests
    module Appeals
      class Appeals
        include Swagger::Blocks

        swagger_path '/v0/appeals' do
          operation :get do
            extend Swagger::Responses::AuthenticationError

            key :description, 'returns list of appeals for a user'
            key :operationId, 'getAppeals'
            key :tags, %w[appeals]

            parameter :authorization

            response 200 do
              key :description, 'Array of appeals and related data [alerts, events, evidence, issues]'
              schema do
                key :'$ref', :Appeal
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
end
