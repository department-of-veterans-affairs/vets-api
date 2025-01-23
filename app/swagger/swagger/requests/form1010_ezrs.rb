# frozen_string_literal: true

module Swagger
  module Requests
    class Form1010Ezrs
      include Swagger::Blocks

      swagger_path '/v0/form1010_ezrs' do
        operation :post do
          extend Swagger::Responses::AuthenticationError
          extend Swagger::Responses::ValidationError
          extend Swagger::Responses::BackendServiceError
          extend Swagger::Responses::InternalServerError

          key :description, 'Submit a 10-10EZR form'
          key :operationId, 'postForm1010Ezr'
          key :tags, %w[benefits_forms]

          parameter :authorization

          parameter do
            key :name, :form
            key :in, :body
            key :description, '10-10EZR form data'
            key :required, true

            schema do
              key :type, :string
            end
          end

          response 200 do
            key :description, 'submit 10-10EZR form response'
            schema do
              key :$ref, :Form1010EzrSubmissionResponse
            end
          end
        end
      end

      swagger_schema :Form1010EzrSubmissionResponse do
        key :required, %i[formSubmissionId timestamp success]

        property :formSubmissionId, type: %i[integer null], example: nil
        property :timestamp, type: %i[string null], example: nil
        property :success, type: :boolean
      end
    end
  end
end
