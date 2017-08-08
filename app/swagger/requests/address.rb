# frozen_string_literal: true
module Swagger
  module Requests
    class Address
      include Swagger::Blocks

      swagger_path '/v0/address/countries' do
        operation :get do
          extend Swagger::Responses::AuthenticationError

          key :description, 'Get a list of the PCIU supported countries'
          key :operationId, 'getCountries'
          key :tags, %w(
            evss
          )

          parameter :authorization

          response 200 do
            key :description, 'Response is OK'
            schema do
              key :'$ref', :Countries
            end
          end
        end
      end

      swagger_path '/v0/address/states' do
        operation :get do
          extend Swagger::Responses::AuthenticationError

          key :description, 'Get a list of the PCIU supported states'
          key :operationId, 'getStates'
          key :tags, %w(
            evss
          )

          parameter :authorization

          response 200 do
            key :description, 'Response is OK'
            schema do
              key :'$ref', :States
            end
          end
        end
      end
    end
  end
end
