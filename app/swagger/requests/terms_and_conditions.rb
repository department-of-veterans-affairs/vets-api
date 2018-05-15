# frozen_string_literal: true

module Swagger
  module Requests
    class TermsAndConditions
      include Swagger::Blocks

      swagger_path '/v0/terms_and_conditions' do
        operation :get do
          extend Swagger::Responses::AuthenticationError

          key :description, 'Get the list of terms and conditions'
          key :operationId, 'getAllTermsAndConditions'
          key :tags, [
            'terms_and_conditions'
          ]

          response 200 do
            key :description, 'get terms and conditions response'
            schema do
              key :'$ref', :TermsAndConditions
            end
          end
        end
      end

      swagger_path '/v0/terms_and_conditions/{name}/versions/latest' do
        operation :get do
          extend Swagger::Responses::AuthenticationError

          key :description, 'Get the latest version of the named terms and conditions'
          key :operationId, 'getTermsAndConditions'
          key :tags, [
            'terms_and_conditions'
          ]

          parameter do
            key :name, :name
            key :in, :path
            key :description, 'Name of the terms'
            key :required, true
            key :type, :string
          end

          response 200 do
            key :description, 'get named terms and conditions response'
            schema do
              key :'$ref', :TermsAndConditionsSingle
            end
          end

          response 404 do
            key :description, 'terms not found'
            schema do
              key :'$ref', :Errors
            end
          end
        end
      end

      swagger_path '/v0/terms_and_conditions/{name}/versions/latest/user_data' do
        operation :get do
          extend Swagger::Responses::AuthenticationError

          key :description, 'Get information about the user acceptance for the named terms and conditions'
          key :operationId, 'getTermsAndConditionsUserData'
          key :tags, [
            'terms_and_conditions'
          ]

          parameter :authorization

          parameter do
            key :name, :name
            key :in, :path
            key :description, 'Name of the terms'
            key :required, true
            key :type, :string
          end

          response 200 do
            key :description, 'get user data for terms and conditions response'
            schema do
              key :'$ref', :TermsAndConditionsAcceptance
            end
          end

          response 404 do
            key :description, 'terms not found'
            schema do
              key :'$ref', :Errors
            end
          end
        end

        operation :post do
          extend Swagger::Responses::AuthenticationError

          key :description, 'Create a user acceptance for the named terms and conditions'
          key :operationId, 'createTermsAndConditionsAcceptance'
          key :tags, [
            'terms_and_conditions'
          ]

          parameter :authorization

          parameter do
            key :name, :name
            key :in, :path
            key :description, 'Name of the terms'
            key :required, true
            key :type, :string
          end

          response 200 do
            key :description, 'create an acceptance for the terms and conditions response'
            schema do
              key :'$ref', :TermsAndConditionsAcceptance
            end
          end

          response 404 do
            key :description, 'terms not found'
            schema do
              key :'$ref', :Errors
            end
          end

          response 422 do
            key :description, 'errors on acceptance creation'
            schema do
              key :'$ref', :Errors
            end
          end
        end
      end
    end
  end
end
