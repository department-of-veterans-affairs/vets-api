# frozen_string_literal: true

module Swagger
  module Requests
    class Profile
      include Swagger::Blocks

      swagger_path '/v0/profile/email' do
        operation :get do
          extend Swagger::Responses::AuthenticationError

          key :description, 'Get a users email address information'
          key :operationId, 'getEmailAddress'
          key :tags, %w[
            profile
          ]

          parameter :authorization

          response 200 do
            key :description, 'Response is OK'
            schema do
              property :email_address, type: :string, example: 'john@example.com'
              property :effective_at, type: :string, example: '2018-02-27T14:41:32.283Z'
            end
          end
        end
      end
    end
  end
end
