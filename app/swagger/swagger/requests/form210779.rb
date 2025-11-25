# frozen_string_literal: true

module Swagger
  module Requests
    class Form210779
      include Swagger::Blocks

      swagger_path '/v0/form210779' do
        operation :post do
          extend Swagger::Responses::ValidationError
          extend Swagger::Responses::SavedForm
          extend Swagger::Responses::UnprocessableEntityError

          key :description,
              'Submit a 21-0779 form (Request for Nursing Home Information in Connection with Claim for ' \
              'Aid and Attendance) - STUB IMPLEMENTATION for frontend development'
          key :operationId, 'submitForm210779'
          key :tags, %w[benefits_forms]

          parameter :optional_authorization

          parameter do
            key :name, :form
            key :in, :body
            key :description, 'Form 21-0779 submission data'
            key :required, true
            schema do
              VetsJsonSchema::SCHEMAS['21-0779']['properties']
            end
          end
        end
      end

      swagger_path '/v0/form210779/download_pdf/{guid}' do
        operation :get do
          extend Swagger::Responses::RecordNotFoundError

          key :description, 'Download the submitted 21-0779 PDF form'
          key :operationId, 'downloadForm210779Pdf'
          key :tags, %w[benefits_forms]
          key :produces, ['application/pdf', 'application/json']

          parameter :optional_authorization

          parameter do
            key :name, 'guid'
            key :in, :path
            key :description, 'the guid from the form submission response'
            key :required, true
            key :type, :string
          end

          response 200 do
            key :description, 'PDF file successfully generated and ready for download'

            schema do
              key :type, :file
            end
          end

          response 403 do
            key :description, 'Feature flag disabled'
          end
        end
      end

      VetsJsonSchema::SCHEMAS.fetch('21-0779')['definitions'].each do |key, value|
        swagger_schema(key, value)
      end
    end
  end
end
