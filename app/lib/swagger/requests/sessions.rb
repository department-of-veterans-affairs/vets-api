# frozen_string_literal: true
module Swagger
  module Requests
    class Sessions
      include Swagger::Blocks

      swagger_path '/v0/sessions/new' do
        operation :get do
          key :description, 'Get started creating a new session'
          key :operationId, 'newSession'
          key :tags, [
            'authentication'
          ]
          parameter do
            key :name, :level
            key :in, :query
            key :description, 'LOA level of the new session, 1 or 3'
            key :required, true
            key :type, :integer
            key :format, :int32
          end
          response 200 do
            key :description, 'new session response'
            schema do
              key :'$ref', :NewSession
            end
          end
        end
      end

      swagger_path '/v0/sessions' do
        operation :delete do
          extend Swagger::Responses::AuthenticationError

          key :description, 'Terminate the current session'
          key :operationId, 'endSession'
          key :tags, [
            'authentication'
          ]

          parameter do
            key :name, 'Authorization'
            key :in, :header
            key :description, 'The authorization method and token value'
            key :required, true
            key :type, :string
          end

          response 202 do
            key :description, 'end session response'
            schema do
              key :'$ref', :EndSession
            end
          end
        end
      end

      swagger_schema :NewSession, required: [:authenticate_via_get] do
        property :authenticate_via_get, type: :string
      end

      swagger_schema :EndSession, required: [:logout_via_get] do
        property :logout_via_get, type: :string
      end
    end
  end
end
