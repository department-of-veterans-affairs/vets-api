# frozen_string_literal: true

require 'hca/enrollment_eligibility/status_matcher'

module Swagger
  module Requests
    class HealthCareApplications
      include Swagger::Blocks

      swagger_path '/v0/health_care_applications/rating_info' do
        operation :get do
          key :description, 'Get the user\'s service connected disability rating'
          key :operationId, 'getDisabilityRating'
          key :tags, %w[benefits_forms]

          response 200 do
            key :description, 'disability rating response'

            schema do
              property :data, type: :object do
                key :required, %i[attributes]
                property :id, type: :string
                property :type, type: :string

                property :attributes, type: :object do
                  key :required, %i[user_percent_of_disability]

                  property :user_percent_of_disability, type: :integer
                end
              end
            end
          end
        end
      end

      swagger_path '/v0/health_care_applications/{id}' do
        operation :get do
          key :description, 'Show the status of a health care application'
          key :operationId, 'getHealthCareApplication'
          key :tags, %w[benefits_forms]

          parameter do
            key :name, :id
            key :in, :path
            key :description, 'ID of the application'
            key :required, true
            key :type, :string
          end

          response 200 do
            key :description, 'get HCA response'

            schema do
              property :data, type: :object do
                key :required, %i[attributes]
                property :id, type: :string
                property :type, type: :string
                property :attributes, type: :object do
                  key :required, %i[state]

                  property :state, type: :string
                  property :form_submission_id, type: %i[string null]
                  property :timestamp, type: %i[string null]
                end
              end
            end
          end
        end
      end

      swagger_path '/v0/health_care_applications' do
        operation :post do
          extend Swagger::Responses::ValidationError
          extend Swagger::Responses::BackendServiceError

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
              key :$ref, :HealthCareApplicationSubmissionResponse
            end
          end
        end
      end

      swagger_path '/v0/health_care_applications/enrollment_status' do
        operation :get do
          key :description, 'Check the status of a health care application.'\
                            ' Non-logged in users must pass query parameters with user attributes.'\
                            ' No parameters needed for logged in loa3 users.'
          key :operationId, 'enrollmentStatusHealthCareApplication'
          key :tags, %w[benefits_forms]

          parameter :optional_authorization

          [
            {
              name: 'userAttributes[veteranFullName][first]',
              description: 'user first name'
            },
            {
              name: 'userAttributes[veteranFullName][middle]',
              description: 'user middle name'
            },
            {
              name: 'userAttributes[veteranFullName][last]',
              description: 'user last name'
            },
            {
              name: 'userAttributes[veteranFullName][suffix]',
              description: 'user name suffix'
            },
            {
              name: 'userAttributes[veteranDateOfBirth]',
              description: 'user date of birth'
            },
            {
              name: 'userAttributes[veteranSocialSecurityNumber]',
              description: 'user ssn'
            },
            {
              name: 'userAttributes[gender]',
              description: 'user gender'
            }
          ].each do |attribute_data|
            parameter do
              key :name, attribute_data[:name]
              key :in, :query
              key :description, attribute_data[:description]
              key :required, false
              key :type, :string
            end
          end

          response 200 do
            key :description, 'enrollment_status response'

            schema do
              property :application_date, type: %i[string null], example: '2018-12-27T00:00:00.000-06:00'
              property :enrollment_date, type: %i[string null], example: '2018-12-27T17:15:39.000-06:00'
              property :preferred_facility, type: %i[string null], example: '988 - DAYT20'
              property :parsed_status,
                       type: :string,
                       example: HCA::EnrollmentEligibility::Constants::ENROLLED,
                       enum: HCA::EnrollmentEligibility::StatusMatcher::ELIGIBLE_STATUS_CATEGORIES
              property :effective_date, type: :string, example: '2019-01-02T21:58:55.000-06:00'
              property :priority_group, type: %i[string null], example: 'Group 3'
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
              key :$ref, :HealthCareApplicationHealthcheckResponse
            end
          end
        end
      end

      swagger_schema :HealthCareApplicationSubmissionResponse do
        key :required, %i[formSubmissionId timestamp success]

        property :formSubmissionId, type: :integer
        property :timestamp, type: :string
        property :success, type: :boolean
      end

      swagger_schema :HealthCareApplicationHealthcheckResponse do
        key :required, %i[formSubmissionId timestamp]

        property :formSubmissionId, type: :integer
        property :timestamp, type: :string
      end
    end
  end
end
