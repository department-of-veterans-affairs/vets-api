# frozen_string_literal: true

module Swagger
  module Requests
    class Form210779
      include Swagger::Blocks

      swagger_path '/v0/form210779' do
        operation :post do
          extend Swagger::Responses::SavedForm

          key :description,
              'Submit a 21-0779 form (Request for Nursing Home Information in Connection with Claim for ' \
              'Aid and Attendance)'
          key :operationId, 'submitForm210779'
          key :tags, %w[benefits_forms]

          parameter :optional_authorization

          parameter do
            key :name, :form
            key :in, :body
            key :description, 'Form 21-0779 submission data'
            key :required, true

            schema do
              VetsJsonSchema::SCHEMAS['21-0779']['properties'].each do |key, value|
                property key, value
              end
            end
          end

          response 200 do
            key :description, 'Form successfully submitted (stub response)'
            schema do
              key :$ref, :SavedForm
            end
          end
        end
      end

      swagger_path '/v0/form210779/download_pdf' do
        operation :post do
          extend Swagger::Responses::AuthenticationError

          key :description, 'Download a pre-filled 21-0779 PDF form'
          key :operationId, 'downloadForm210779Pdf'
          key :tags, %w[benefits_forms]
          key :produces, ['application/pdf', 'application/json']

          parameter :optional_authorization

          parameter do
            key :name, :form
            key :in, :body
            key :description, 'Form data for PDF generation'
            key :required, true

            schema do
              key :type, :string
              key :description, 'JSON string of form data'
            end
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
