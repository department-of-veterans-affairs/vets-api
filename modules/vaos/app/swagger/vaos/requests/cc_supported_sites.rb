# frozen_string_literal: true

module VAOS
  module Requests
    class CCSupportedSites
      include Swagger::Blocks

      swagger_path '/community_care/supported_sites' do
        operation :get do
          extend Swagger::Responses::AuthenticationError

          key :description, 'returns list of sites supporting community care'
          key :operationId, 'getSupportedSites'
          key :tags, %w[vaos community_care supported_sites]

          parameter :authorization

          parameter do
            key :name, :supported_sites
            key :in, :query
            key :required, true
            key :type, :array
            key :description, 'parent site ids to check for community care support'
          end

          response 200 do
            key :description, 'The list sites supported'
            schema do
              key :'$ref', :CCSupportedSites
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
