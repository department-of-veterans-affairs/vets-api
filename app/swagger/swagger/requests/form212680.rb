# frozen_string_literal: true

module Swagger
  module Requests
    class Form212680
      include Swagger::Blocks
      FORM_ID = '21-2680'

      swagger_path '/v0/form212680/download_pdf' do
        operation :post do
          extend Swagger::Responses::ValidationError
          extend Swagger::Responses::UnprocessableEntityError
          extend Swagger::Responses::InternalServerError
          extend Swagger::Responses::BadRequestError
          extend Swagger::Responses::RecordNotFoundError

          key :description,
              'Generate and download a pre-filled 21-2680 PDF form ' \
              '(Examination for Housebound Status or Permanent Need for Regular Aid and Attendance)'
          key :operationId, 'downloadForm212680Pdf'
          key :tags, %w[benefits_forms]
          key :produces, ['application/pdf', 'application/json']
          parameter :optional_authorization
          parameter do
            key :name, :form
            key :in, :body
            key :description, 'Form 21-2680 data for PDF generation'
            key :required, true
            schema do
              VetsJsonSchema::SCHEMAS[FORM_ID]['properties']
            end
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
