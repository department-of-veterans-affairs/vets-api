# frozen_string_literal: true

module Swagger
  module Requests
    module Form1010cg
      class Attachments
        include Swagger::Blocks

        swagger_path '/v0/form1010cg/attachments' do
          operation :post do
            extend Swagger::Responses::ValidationError
            extend Swagger::Responses::BadRequestError

            key :description, 'Upload Power of Attorney attachment for a caregivers assistance claim.'

            parameter do
              key :name, :attachment
              key :in, :body
              key :description, 'The document data'
              key :required, true

              schema do
                key :required, %i[file_data]
                property :file_data, type: :string, example: 'my-poa.png'
                property :password, type: :string, example: 'MyPassword123'
              end
            end

            response 200 do
              key :description, 'Ok'

              schema do
                key :required, [:data]

                property :data, type: :object do
                  key :required, %i[id type attributes]

                  property :id do
                    key :description, 'The record\'s identifier'
                    key :type, :string
                    key :example, '"67"'
                  end

                  property :type do
                    key :description, 'This is always "form1010cg_attachments"'
                    key :type, :string
                    key :example, 'form1010cg_attachments'
                  end

                  property :attributes, type: :object do
                    key :required, [:guid]

                    property :guid do
                      key :description, 'The document\'s GUID. To attach this document to a claim,\\
                                         include this id the claim\'s submission payload.'
                      key :type, :string
                      key :example, '834d9f51-d0c7-4dc2-9f2e-9b722db98069'
                    end
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end
