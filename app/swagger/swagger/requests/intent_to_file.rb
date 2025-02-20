# frozen_string_literal: true

module Swagger
  module Requests
    class IntentToFile
      include Swagger::Blocks

      swagger_path '/v0/intent_to_file' do
        operation :get do
          extend Swagger::Responses::AuthenticationError

          key :description, 'Get a list of all Intent To File requests made by the veteran'
          key :operationId, 'getIntentToFile'
          key :tags, %w[form_526]

          parameter :authorization

          response 200 do
            key :description, 'Response is OK'
            schema do
              key :$ref, :IntentToFiles
            end
          end
        end
      end

      swagger_path '/v0/intent_to_file/{type}' do
        operation :post do
          extend Swagger::Responses::AuthenticationError

          key :description, 'Creates a new Intent To File for the veteran'
          key :operationId, 'postIntentToFile'
          key :tags, %w[form_526]

          parameter :authorization

          parameter do
            key :name, :type
            key :in, :path
            key :description, 'ITF type. Allowed values: compensation'
            key :required, true
            key :type, :string
          end

          response 200 do
            key :description, 'Response is OK'
            schema do
              key :$ref, :IntentToFile
            end
          end
        end
      end
    end
  end
end
