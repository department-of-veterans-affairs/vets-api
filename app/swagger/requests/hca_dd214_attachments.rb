# frozen_string_literal: true

module Swagger
  module Requests
    class HcaDd214Attachments
      include Swagger::Blocks

      swagger_path '/v0/hca_dd214_attachments' do
        operation :post do
          key :description, 'Submit a health care application dd214 attachment'
          key :operationId, 'postHealthCareApplicationDd214'
          key :tags, %w[benefits_forms]

          parameter :optional_authorization

          parameter do
            key :name, :hca_dd214_attachment
            key :in, :body
            key :description, 'DD214 data'
            key :required, true

            schema do
              key :required, %i[file_data]

              property :file_data, type: :string
            end
          end

          response 200 do
            key :description, 'submit hca dd214 response'
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
