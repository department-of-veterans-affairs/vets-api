# frozen_string_literal: true

module Swagger
  module Requests
    class BenefitsClaims
      include Swagger::Blocks

      swagger_path '/v0/benefits_claims/{id}' do
        operation :get do
          extend Swagger::Responses::AuthenticationError
          extend Swagger::Responses::ForbiddenError
          extend Swagger::Responses::RecordNotFoundError
          extend Swagger::Responses::BadRequestError
          extend Swagger::Responses::InternalServerError
          extend Swagger::Responses::BadGatewayError
          extend Swagger::Responses::ServiceUnavailableError

          key :description, 'Get details for a single benefits claim'
          key :operationId, 'getBenefitsClaimById'
          key :tags, %w[benefits_claims]

          parameter :authorization

          parameter do
            key :name, :id
            key :in, :path
            key :description, 'Lighthouse claim ID (e.g., 600383363)'
            key :required, true
            key :type, :string
          end

          response 200 do
            key :description, 'Successfully retrieved claim details'
            schema do
              key :type, :object
              key :required, [:data]

              property :data do
                key :$ref, :BenefitsClaimDetail
              end
            end
          end

          response 429 do
            key :description, 'Too Many Requests: Rate limit exceeded'
            schema '$ref': :Errors
          end

          response 504 do
            key :description, 'Gateway Timeout: Lighthouse failed to respond in a timely manner'
            schema '$ref': :Errors
          end
        end
      end

      swagger_path '/v0/benefits_claims/failed_upload_evidence_submissions' do
        operation :get do
          extend Swagger::Responses::AuthenticationError
          extend Swagger::Responses::ForbiddenError
          extend Swagger::Responses::RecordNotFoundError

          key :description,
              'Get a list of failed evidence submissions for all claims for a user.'
          key :operationId, 'getFailedUploadEvidenceSubmissions'
          key :tags, %w[benefits_claims]

          parameter :authorization

          response 200 do
            key :description, 'Response is OK'
            schema do
              key :type, :object
              key :required, [:data]

              property :data do
                key :type, :array
                items do
                  key :$ref, :FailedEvidenceSubmission
                end
              end
            end
          end

          response 504 do
            key :description, 'Gateway Timeout: Lighthouse failed to respond in a timely manner'
            schema '$ref': :Errors
          end
        end
      end
    end
  end
end
