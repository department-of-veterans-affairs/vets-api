# frozen_string_literal: true

module Swagger
  module Requests
    class DisabilityCompensationForm
      include Swagger::Blocks

      swagger_path '/v0/disability_compensation_form/rated_disabilities' do
        operation :get do
          extend Swagger::Responses::AuthenticationError
          extend Swagger::Responses::BadGatewayError
          extend Swagger::Responses::BadRequestError
          extend Swagger::Responses::ForbiddenError

          key :description, 'Get a list of previously rated disabilities for a veteran'
          key :operationId, 'getRatedDisabilities'
          key :tags, %w[form_526]

          parameter :authorization

          response 200 do
            key :description, 'Response is OK'
            schema do
              key :$ref, :RatedDisabilities
            end
          end
        end
      end

      swagger_path '/v0/disability_compensation_form/suggested_conditions{params}' do
        operation :get do
          extend Swagger::Responses::AuthenticationError

          key :description, 'Given part of a condition name (medical or lay), return a list of matching conditions'
          key :operationId, 'getSuggestedConditions'
          key :tags, %w[form_526]

          parameter :authorization

          parameter do
            key :name, :params
            key :description,
                'part of a medical term of lay term for a medical condition; for example "?name_part=anxiety"'
            key :in, :path
            key :type, :string
            key :required, true
          end

          response 200 do
            key :description, 'Returns a list of conditions'
            schema do
              key :$ref, :SuggestedConditions
            end
          end
        end
      end

      swagger_path '/v0/disability_compensation_form/submit_all_claim' do
        operation :post do
          extend Swagger::Responses::AuthenticationError
          extend Swagger::Responses::ForbiddenError
          extend Swagger::Responses::ValidationError

          key :description, 'Submit the disability compensation v2 application for a veteran'
          key :operationId, 'postSubmitFormV2'
          key :tags, %w[form_526]

          parameter :authorization

          parameter do
            key :name, :form526
            key :in, :body
            key :description, 'Disability Compensation form data'
            key :required, true
            schema do
              key :$ref, :Form526SubmitV2
            end
          end

          response 200 do
            key :description, 'Response is OK'
            schema do
              key :$ref, :SubmitDisabilityForm
            end
          end
        end
      end

      swagger_path '/v0/disability_compensation_form/submission_status/{job_id}' do
        operation :get do
          extend Swagger::Responses::AuthenticationError
          extend Swagger::Responses::ForbiddenError
          extend Swagger::Responses::RecordNotFoundError

          key :description, 'Check the status of a submission job'
          key :operationId, 'getSubmissionStatus'
          key :tags, %w[form_526]

          parameter :authorization

          parameter do
            key :name, :job_id
            key :description, 'the job_id for the submission to check the status of'
            key :in, :path
            key :type, :string
            key :required, true
          end

          response 200 do
            key :description, 'Returns the status of a given submission'
            schema do
              key :$ref, :JobStatus
            end
          end
        end
      end

      swagger_path '/v0/disability_compensation_form/rating_info' do
        operation :get do
          extend Swagger::Responses::AuthenticationError
          extend Swagger::Responses::ForbiddenError

          key :description, 'Get the total combined disability rating for a veteran'
          key :operationId, 'getRatingInfo'
          key :tags, %w[form_526]

          parameter :authorization

          response 200 do
            key :description, 'Response is OK'
            schema do
              key :$ref, :RatingInfo
            end
          end
        end
      end

      swagger_path '/v0/disability_compensation_form/separation_locations' do
        operation :get do
          extend Swagger::Responses::AuthenticationError
          extend Swagger::Responses::BadGatewayError
          extend Swagger::Responses::ServiceUnavailableError
          extend Swagger::Responses::ForbiddenError

          key :description, 'Get the separation locations from EVSS'
          key :operationId, 'getIntakeSites'
          key :tags, %w[form_526]

          parameter :authorization

          response 200 do
            key :description, 'Response is OK'
            schema do
              key :$ref, :SeparationLocations
            end
          end

          response 403 do
            key :description, 'forbidden user'

            schema do
              key :$ref, :Errors
            end
          end
        end
      end
    end
  end
end
