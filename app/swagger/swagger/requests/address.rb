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
          key :tags, %w[
            benefits_info
          ]

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
          key :tags, %w[
            benefits_info
          ]

          parameter :authorization

          response 200 do
            key :description, 'Response is OK'
            schema do
              key :'$ref', :States
            end
          end
        end
      end

      swagger_path '/v0/address' do
        operation :get do
          extend Swagger::Responses::AuthenticationError

          key :description, 'Get a users corp address'
          key :operationId, 'getAddress'
          key :tags, %w[
            benefits_info
          ]

          parameter :authorization

          response 200 do
            key :description, 'Response is OK'
            schema do
              key :'$ref', :Address
            end
          end
        end
      end

      swagger_path '/v0/address' do
        operation :put do
          extend Swagger::Responses::AuthenticationError

          key :description, 'Updates a users corp address'
          key :operationId, 'getAddress'
          key :tags, %w[
            benefits_info
          ]

          parameter :authorization
          parameter do
            key :name, :body
            key :in, :body
            key :description, 'Options to include in generated PDF'
            key :required, true

            schema do
              property :type, type: :string, enum:
                %w[
                  DOMESTIC
                  INTERNATIONAL
                  MILITARY
                ], example: 'DOMESTIC'
              property :address_one, type: :string, example: '140 Rock Creek Church Rd NW'
              property :address_two, type: :string, example: ''
              property :address_three, type: :string, example: ''
              property :city, type: :string, example: 'Washington'
              property :state_code, type: :string, example: 'DC'
              property :zip_code, type: :string, example: '20011'
              property :zip_suffix, type: :string, example: '1865'
            end
          end

          response 200 do
            key :description, 'Response is OK'
            schema do
              key :'$ref', :Address
            end
          end
        end
      end
    end
  end
end
