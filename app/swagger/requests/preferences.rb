# frozen_string_literal: true

module Swagger
  module Requests
    class Preferences
      include Swagger::Blocks
      swagger_path '/v0/preferences' do
        operation :get do
          extend Swagger::Responses::AuthenticationError
          key :description, 'Gets a particular Preference with PreferenceChoices'
          key :operationId, 'getPreference'
          key :tags, %w[
            preferences
          ]
          parameter :authorization
          parameter :code
          response 200 do
            key :description, 'Response is OK'
            schema do
              key :'$ref', :Preference
            end
          end
        end
      end
    end
  end
end
