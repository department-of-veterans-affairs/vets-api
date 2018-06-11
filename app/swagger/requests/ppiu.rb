# frozen_string_literal: true

module Swagger
  module Requests
    class PPIU
      include Swagger::Blocks

      swagger_path '/v0/ppiu' do
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
      end
    end
  end
end
