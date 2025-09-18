# frozen_string_literal: true

module Swagger
  module Requests
    class BenefitsClaims
      include Swagger::Blocks

      swagger_path '/v0/benefits_claims/failed_upload_evidence_submissions' do
        operation :get do
          extend Swagger::Responses::AuthenticationError
          extend Swagger::Responses::ForbiddenError

          key :description,
              'Get a list of failed evidence submissions for all claims for a user.'
          key :operationId, 'getFailedUploadEvidenceSubmissions'
          key :tags, %w[benefits_claims]

          parameter :authorization

          response 200 do
            key :description, 'Response is OK'
            schema do
              key :type, :array

              items do
                key :$ref, :FailedEvidenceSubmission
              end
            end
          end
        end
      end
    end
  end
end
