# frozen_string_literal: true

module Swagger
  module Requests
    class PPIU
      include Swagger::Blocks

      swagger_path '/v0/ppiu/payment_information' do
        operation :get do
          extend Swagger::Responses::AuthenticationError

          key :description, 'Get a veterans payment information'
          key :operationId, 'getPaymentInformation'
          key :tags, %w[form_526]

          parameter :authorization

          response 200 do
            key :description, 'Response is OK'
            schema do
              key :'$ref', :PPIU
            end
          end
        end

        operation :put do
          extend Swagger::Responses::AuthenticationError

          key :description, 'Update a veterans payment information'
          key :operationId, 'postPaymentInformation'
          key :tags, %w[form_526]

          parameter :authorization

          parameter do
            key :name, :body
            key :in, :body
            key :description, 'Payment information to be updated for the user'
            key :required, true

            schema do
              property :account_type, type: :string, example: 'Checking'
              property :financial_institution_name, type: :string, example: 'Bank Of America'
              property :account_number, type: :string, example: '1234567890'
              property :financial_institution_routing_number, type: :string, pattern: /^\d{9}$/, example: '123456789'
            end
          end

          response 200 do
            key :description, 'Response is OK'
            schema do
              key :'$ref', :PPIU
            end
          end
        end
      end
    end
  end
end
