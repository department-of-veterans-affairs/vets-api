# frozen_string_literal: true

module Swagger
  module Requests
    module Form1010cg
      class Attachments
        include Swagger::Blocks

        swagger_path '/v0/form1010cg/attachments' do
          operation :post do
            extend Swagger::Responses::ValidationError

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

            response 201 do
              key :description, 'Created'

              schema do
                key :required, [:data]

                property :data, type: :object do
                  key :required, [:attributes]

                  property :id do
                    key :description, '"id" is never returned (use attributes.guid)'
                    key :type, :string
                    key :example, ''
                  end

                  property :type do
                    key :description, 'This is always "form1010cg_attachments"'
                    key :type, :string
                    key :example, 'form1010cg_attachments'
                  end

                  property :attributes, type: :object do
                    key :required, %i[guid created_at]

                    property :guid do
                      key :description, 'The document\'s GUID. To attach this document to a claim,\\
                                         include this id the claim\'s submission payload.'
                      key :type, :string
                      key :example, '90cd36bb-4bb0-49b3-a957-2ce7ad241dd7'
                    end

                    property :created_at do
                      key :type, :string
                      key :example, '1973-01-01T05:00:00.000+00:00'
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
