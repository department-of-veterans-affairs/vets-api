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
          key :description, 'Check the status of a health care application.' \
                            ' Non-logged in users must pass query parameters with user attributes.' \
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
              property :can_submit_financial_info, type: %i[boolean null], example: true
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

      swagger_path '/v0/health_care_applications/facilities' do
        operation :get do
          key :description, 'Retrieve a list of active healthcare facilities'
          key :operationId, 'getFacilities'
          key :tags, %w[benefits_forms]

          parameter :optional_authorization

          parameter do
            key :name, :zip
            key :in, :query
            key :description, 'ZIP code for filtering facilities'
            key :required, false
            key :type, :string
          end

          parameter do
            key :name, :state
            key :in, :query
            key :description, 'State for filtering facilities'
            key :required, false
            key :type, :string
          end

          parameter do
            key :name, :lat
            key :in, :query
            key :description, 'Latitude for filtering facilities'
            key :required, false
            key :type, :string
          end

          parameter do
            key :name, :long
            key :in, :query
            key :description, 'Longitude for filtering facilities'
            key :required, false
            key :type, :string
          end

          parameter do
            key :name, :radius
            key :in, :query
            key :description, 'The radius around the location for facility search.'
            key :required, false
            key :type, :string
          end

          parameter do
            key :name, :bbox
            key :in, :query
            key :description, 'Bounding box for facility search'
            key :required, false
            key :type, :string
          end

          parameter do
            key :name, :visn
            key :in, :query
            key :description, 'VISN code for filtering facilities'
            key :required, false
            key :type, :string
          end

          parameter do
            key :name, :type
            key :in, :query
            key :description, 'Type of facility'
            key :required, false
            key :type, :string
          end

          parameter do
            key :name, :services
            key :in, :query
            key :description, 'Services offered at the facility'
            key :required, false
            key :type, :string
          end

          parameter do
            key :name, :mobile
            key :in, :query
            key :description, 'Filter by mobile facilities'
            key :required, false
            key :type, :boolean
          end

          parameter do
            key :name, :page
            key :in, :query
            key :description, 'Page number for pagination'
            key :required, false
            key :type, :integer
          end

          parameter do
            key :name, :per_page
            key :in, :query
            key :description, 'Number of facilities per page'
            key :required, false
            key :type, :integer
          end

          parameter do
            key :name, :facilityIds
            key :in, :query
            key :description, 'Array of facility IDs'
            key :type, :array
            items do
              key :type, :string
            end
            key :collectionFormat, :multi
          end

          response 200 do
            key :description, 'Successful response with a list of healthcare facilities'
            schema do
              key :$ref, :Facilities
            end
          end
        end
      end

      swagger_path '/v0/health_care_applications/download_pdf' do
        operation :post do
          key :description, 'Download a pre-filled 10-10EZ PDF form.'
          key :tags, %w[benefits_forms]

          parameter do
            key :name, :form
            key :in, :body
            key :description, 'The form data used to fill the PDF form.'
            key :required, true
            schema do
              key :type, :string
            end
          end

          response 200 do
            key :description, 'PDF form download'

            schema do
              property :data, type: :string, format: 'binary'
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
