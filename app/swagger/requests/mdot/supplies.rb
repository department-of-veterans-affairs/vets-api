# frozen_string_literal: true

module Swagger
  module Requests
    module MDOT
      class Supplies
        include Swagger::Blocks

        swagger_path '/v0/mdot/supplies' do
          operation :get do
            extend Swagger::Responses::AuthenticationError

            key :description, 'returns a list of medical devices and supplies available for reorder for the veteran'
            key :operationId, 'getSupplies'
            key :tags, %w[supplies]

            response 200 do
              key :description, '200 passes the response from the upstream DLC API'
              schema do
                key :'$ref', :Supplies
              end
            end

            response 404 do
              key :description, 'Not found: medical devices and supplies not found for user'
              schema do
                key :'$ref', :Errors
              end
            end

            response 502 do
              key :description, 'Bad Gateway: the upstream DLC API returned an invalid response (500+)'
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
