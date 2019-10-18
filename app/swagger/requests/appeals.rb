# frozen_string_literal: true

module Swagger
  module Requests
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

      swagger_path '/v0/appeals/higher_level_reviews/{uuid}' do
        operation :get do

          key :description, 'This endpoint returns the details of a specific Higher Level Review'
          key :operationId, 'showHigherLevelReview'
          key :tags, %w[higher_level_reviews]

          parameter do
            key :name, :uuid
            key :in, :path
            key :description, "UUID of a higher level review"
            key :required, true

            schema do
              property :data,
                       type: :string,
                       format: :uuid,
                       pattern: '^[0-9a-fA-F]{8}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{12}$'

            end
          end

          response 200 do
            key :description, 'Response is OK'
            schema do
              key :'$ref', :HigherLevelReview
            end
          end

          response 404 do
            key :description, 'ID not found'
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

      swagger_path 'v0/appeals/higher_level_review/intake_status/{intake_id}' do
        operation :get do
        end
      end
    end
  end
end
