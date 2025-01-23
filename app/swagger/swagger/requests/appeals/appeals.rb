# frozen_string_literal: true

require 'decision_review/schemas'
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
            key :tags, %w[benefits_status]

            parameter :authorization

            response 200 do
              key :description, '200 passes the response from the upstream appeals API'
              schema '$ref': :Appeals
            end

            response 401 do
              key :description, 'User is not authenticated (logged in)'
              schema '$ref': :Errors
            end

            response 403 do
              key :description, 'Forbidden: user is not authorized for appeals'
              schema '$ref': :Errors
            end

            response 404 do
              key :description, 'Not found: appeals not found for user'
              schema '$ref': :Errors
            end

            response 422 do
              key :description, 'Unprocessable Entity: one or more validations has failed'
              schema '$ref': :Errors
            end

            response 502 do
              key :description, 'Bad Gateway: the upstream appeals app returned an invalid response (500+)'
              schema '$ref': :Errors
            end
          end
        end
      end
    end
  end
end
