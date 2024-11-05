# frozen_string_literal: true

module Swagger
  module Requests
    class Form1010EzrAttachments
      include Swagger::Blocks

      swagger_path '/v0/form1010_ezr_attachments' do
        operation :post do
          extend Swagger::Responses::BadRequestError
          extend Swagger::Responses::UnprocessableEntityError
          extend Swagger::Responses::AuthenticationError
          extend Swagger::Responses::InternalServerError

          key :description, 'Submit a 10-10EZR form attachment'
          key :operationId, 'postForm1010EzrAttachment'
          key :tags, %w[benefits_forms]

          parameter :authorization

          parameter do
            key :name, :form1010_ezr_attachment
            key :in, :body
            key :description, '10-10EZR form attachment data'
            key :required, true

            schema do
              key :required, %i[file_data]
              property :file_data, type: :string, example: 'filename.pdf'
              property :password, type: :string, example: 'My Password'
            end
          end

          response 200 do
            key :description, 'submit 10-10EZR attachment response'
            schema do
              property :data, type: :object do
                key :required, %i[attributes]
                property :id, type: :string
                property :type, type: :string
                property :attributes, type: :object do
                  key :required, %i[guid]
                  property :guid, type: :string
                end
              end
            end
          end
        end
      end
    end
  end
end
