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

      swagger_path '/v0/address' do
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
              key :'$ref', :Address
            end
          end
        end
      end

      swagger_path '/v0/address' do
        operation :post do
          extend Swagger::Responses::AuthenticationError

          key :description, 'Get a list of the PCIU supported states'
          key :operationId, 'getStates'
          key :tags, %w(
            evss
          )

          parameter :authorization
          parameter do
            key :name, :body
            key :in, :body
            key :description, 'Options to include in generated PDF'
            key :required, false

            schema do
              property :type, type: :string, enum: %w(
                D
                I
                M
              ), example: 'D'
              property :address_effective_date, type: :string, example: '2015-10-01T04:00:00.000+0000'
              property :address_one, type: :string, example: '140 Rock Creek Church Rd NW'
              property :address_two, type: :string, example: 'Building A'
              property :address_three, type: :string, example: 'Apt 514'
              property :city, type: :string, example: 'Washington'
              property :state_code, type: :string, example: 'DC'
              property :zip_code, type: :string, example: '20011'
              property :zip_suffix, type: :string, example: '1234'
              property :country_name, type: :string, example: 'USA'
              property :military_post_office_type_code, type: :string, enum: %w(
                APO
                FPO
                DPO
              ), example: 'APO'
              property :military_state_code, type: :string, enum: %w(
                AA
                AE
                AP
              ), example: 'AA'
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
