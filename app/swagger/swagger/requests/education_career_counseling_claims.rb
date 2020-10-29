# frozen_string_literal: true

module Swagger
  module Requests
    class EducationCareerCounselingClaims
      include Swagger::Blocks

      swagger_path '/v0/education_career_counseling_claims' do
        operation :post do
          extend Swagger::Responses::ValidationError
          extend Swagger::Responses::SavedForm

          key :description, "Submit a '28-8832' to central mail for career counseling"
          key :operationId, 'requestCareerCounseling'
          key :tags, %w[central_mail_claim]

          parameter :optional_authorization

          parameter do
            key :name, :form
            key :in, :body
            key :description, 'Dependency claim form data'
            key :required, true

            schema do
              key :type, :string
            end
          end
        end
      end
    end
  end
end
