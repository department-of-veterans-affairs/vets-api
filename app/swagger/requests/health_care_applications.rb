# frozen_string_literal: true

module Swagger
  module Requests
    class HealthCareApplications
      include Swagger::Blocks

      swagger_path '/v0/health_care_applications/{id}' do
        operation :get do
          key :description, 'Get a health care application'
          key :operationId, 'getHealthCareApplication'
          key :tags, %w(
            hca
            forms
          )

          parameter do
            key :name, :id
            key :in, :path
            key :description, 'ID of the health care application'
            key :required, true
            key :type, :string
          end

          response 200 do
            key :description, 'get application response'
            schema do
              key :required, [:data]

              property :data, type: :object do
                property :id, type: :string
                property :type, type: :string

                property :attributes, type: :object do
                  property :state, type: :string
                  property :form_submission_id, type: :integer
                  property :timestamp, type: :string
                end
              end
            end
          end
        end
      end

      swagger_path '/v0/health_care_applications' do
        operation :post do
          extend Swagger::Responses::ValidationError

          key :description, 'Submit a health care application'
          key :operationId, 'addHealthCareApplication'
          key :tags, %w[benefits_forms]

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

      # TODO: This is an interal monitoring endpoint, consider
      # removing it from swagger documentation
      swagger_path '/v0/health_care_applications/healthcheck' do
        operation :get do
          key :description, 'Check if the HCA submission service is up'
          key :operationId, 'healthcheckHealthCareApplication'
          key :tags, %w[benefits_forms]

          response 200 do
            key :description, 'health care application health check response'

            schema do
              key :'$ref', :HealthCareApplicationHealthcheckResponse
            end
          end
        end
      end

      swagger_schema :HealthCareApplicationSubmissionResponse do
        key :required, [:data]

        property :data, type: :object do
          property :id, type: :string
          property :type, type: :string

          property :attributes, type: :object do
            property :state, type: :string
          end
        end
      end

      swagger_schema :HealthCareApplicationHealthcheckResponse do
        key :required, %i[formSubmissionId timestamp]

        property :formSubmissionId, type: :integer
        property :timestamp, type: :string
      end
    end
  end
end
