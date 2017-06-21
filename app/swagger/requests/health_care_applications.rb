# frozen_string_literal: true
module Swagger
  module Requests
    class HealthCareApplications
      include Swagger::Blocks

      swagger_path '/v0/health_care_applications' do
        operation :post do
          extend Swagger::Responses::ValidationError
          extend Swagger::Responses::BackendServiceError

          key :description, 'Submit a health care application'
          key :operationId, 'addHealthCareApplication'
          key :tags, %w(
            hca
            forms
          )

          parameter :optional_authorization

          parameter do
            key :name, :form
            key :in, :body
            key :description, 'Health care application form data'
            key :required, true

            schema do
              key :type, :string
            end
          end

          response 200 do
            key :description, 'submit health care application response'
            schema do
              key :'$ref', :HealthCareApplicationSubmissionResponse
            end
          end
        end
      end

      swagger_path '/v0/health_care_applications/healthcheck' do
        operation :get do
          key :description, 'Check if the HCA submission service is up'
          key :operationId, 'healthcheckHealthCareApplication'
          key :tags, ['hca']

          response 200 do
            key :description, 'health care application health check response'

            schema do
              key :'$ref', :HealthCareApplicationHealthcheckResponse
            end
          end
        end
      end

      swagger_schema :HealthCareApplicationSubmissionResponse do
        key :required, [:formSubmissionId, :timestamp, :success]

        property :formSubmissionId, type: :integer
        property :timestamp, type: :string
        property :success, type: :boolean
      end

      swagger_schema :HealthCareApplicationHealthcheckResponse do
        key :required, [:formSubmissionId, :timestamp]

        property :formSubmissionId, type: :integer
        property :timestamp, type: :string
      end
    end
  end
end
