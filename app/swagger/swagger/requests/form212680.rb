# frozen_string_literal: true

module Swagger
  module Requests
    class Form212680
      include Swagger::Blocks
      FORM_ID = '21-2680'

      swagger_path '/v0/form212680' do
        operation :post do
          extend Swagger::Responses::BadRequestError
          extend Swagger::Responses::RecordNotFoundError
          extend Swagger::Responses::SavedForm
          extend Swagger::Responses::UnprocessableEntityError
          extend Swagger::Responses::ValidationError

          key :description,
              "Create a SavedClaim for #{FORM_ID}" \
              '(Examination for Housebound Status or Permanent Need for Regular Aid and Attendance),' \
              'to be used later for PDF generation'
          key :operationId, 'createForm212680Pdf'
          key :tags, %w[benefits_forms]
          key :produces, ['application/json']
          parameter :optional_authorization

          parameter do
            key :name, :form
            key :in, :body
            key :description, "Form #{FORM_ID} submission data"
            key :required, true
            schema do
              VetsJsonSchema::SCHEMAS[FORM_ID]['properties']
            end
          end
        end
      end

      swagger_path '/v0/form212680/download_pdf/{guid}' do
        operation :get do
          extend Swagger::Responses::RecordNotFoundError

          key :description, "Download the submitted #{FORM_ID} PDF form"
          key :operationId, 'downloadForm212680Pdf'
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
        end
      end
      VetsJsonSchema::SCHEMAS.fetch(FORM_ID)['definitions'].each do |key, value|
        swagger_schema(key, value)
      end
    end
  end
end
