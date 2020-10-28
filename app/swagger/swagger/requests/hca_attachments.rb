# frozen_string_literal: true

module Swagger
  module Requests
    class HCAAttachments
      include Swagger::Blocks

      swagger_path '/v0/hca_attachments' do
        operation :post do
          extend Swagger::Responses::BadRequestError
          extend Swagger::Responses::UnprocessableEntityError

          key :description, 'Submit a health care application attachment'
          key :operationId, 'postHealthCareApplicationAttachment'
          key :tags, %w[benefits_forms]

          parameter :optional_authorization

          parameter do
            key :name, :hca_attachment
            key :in, :body
            key :description, 'HCA attachment data'
            key :required, true

            schema do
              key :required, %i[file_data]
              property :file_data, type: :string, example: 'filename.pdf'
              property :password, type: :string, example: 'My Password'
            end
          end

          response 200 do
            key :description, 'submit hca attachment response'
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
