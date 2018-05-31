# frozen_string_literal: true

module Swagger
  module Requests
    class DisabilityCompensationForm
      include Swagger::Blocks

      swagger_path '/v0/disability_compensation_form/rated_disabilities' do
        operation :get do
          extend Swagger::Responses::AuthenticationError

          key :description, 'Get a list of previously rated disabilities for a veteran'
          key :operationId, 'getRatedDisabilities'
          key :tags, %w[form_526]

          parameter :authorization

          response 200 do
            key :description, 'Response is OK'
            schema do
              key :'$ref', :RatedDisabilities
            end
          end
        end
      end

      swagger_path '/v0/disability_compensation_form/submit' do
        operation :post do
          extend Swagger::Responses::AuthenticationError

          key :description, 'Submit the disability compensation increase application for a veteran'
          key :operationId, 'postSubmitForm'
          key :tags, %w[form_526]

          parameter :authorization

          response 200 do
            key :description, 'Response is OK'
          end
        end
      end
    end
  end
end
