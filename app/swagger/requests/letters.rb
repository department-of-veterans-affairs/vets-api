# frozen_string_literal: true
module Swagger
  module Requests
    class Letters
      include Swagger::Blocks

      swagger_path '/v0/letters' do
        operation :get do
          key :description, 'Array of letters available for the user to download'
          key :operationId, 'getLetters'
          key :tags, [
            'evss'
          ]

          parameter :authorization

          response 200 do
            key :description, 'Response is OK'
            schema do
              key :'$ref', :Letter
            end
          end
        end
      end

      swagger_path '/v0/letters/:id' do
        operation :post do
          key :description, 'Download Letter'
          key :operationId, 'getLetter'
          key :tags, [
            'evss'
          ]

          parameter :authorization

          response 200 do
            key :description, 'Response is OK'
            schema do
              key :'$ref', :Letter
            end
          end
        end
      end

      swagger_path '/v0/letters/beneficiary' do
        operation :get do
          key :description, 'Letter beneficiary TBD'
          key :operationId, 'getLetterBeneficiary'
          key :tags, [
            'evss'
          ]

          parameter :authorization

          response 200 do
            key :description, 'Response is OK'
            schema do
              key :'$ref', :Letter
            end
          end
        end
      end

      swagger_schema :Letter do
        key :required, [:data, :meta]

        property :meta, description: 'The response from the EVSS service to vets-api', type: :object do
          key :'$ref', :Meta
        end
        property :data, type: :object do
          property :id, type: :string
          property :type, type: :string
          property :attributes, type: :object do
            property :letters do
              key :type, :array
              items do
                key :'$ref', :Letter
              end
            end
          end
        end
      end

      swagger_schema :Letter do
      end
    end
  end
end
