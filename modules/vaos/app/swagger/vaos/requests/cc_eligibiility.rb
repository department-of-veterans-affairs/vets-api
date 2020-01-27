# frozen_string_literal: true

module VAOS
  module Requests
    class CCEligibility
      include Swagger::Blocks

      swagger_path '/community_care/eligibility' do
        operation :get do
          extend Swagger::Responses::AuthenticationError

          key :description, 'returns object with eligibility flag for specified service type for user'
          key :operationId, 'getEligibility'
          key :tags, %w[vaos community_care eligibility]

          parameter :authorization

          parameter do
            key :name, :service_type
            key :in, :path
            key :required, true
            key :type, :string
            key :description, 'service type to use to check for community care eligibility'
          end

          response 200 do
            key :description, 'Result with elgibility true or false'
            schema do
              key :'$ref', :CCEligibility
            end
          end

          response 400 do
            key :description, 'Bad ServiceType: an unrecognized value was sent for ServiceType'
            schema do
              key :'$ref', :Errors
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
        end
      end
    end
  end
end
