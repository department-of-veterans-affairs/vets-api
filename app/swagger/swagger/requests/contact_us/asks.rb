# frozen_string_literal: true

module Swagger
  module Requests
    module ContactUs
      class Asks
        include Swagger::Blocks

        swagger_path '/v0/ask/asks' do
          operation :post do
            extend Swagger::Responses::ValidationError

            key :description, 'Submit a message'
            key :operationId, 'createsAnInquiry'
            key :tags, %w[contact_us]

            parameter :optional_authorization

            parameter do
              key :name, :body
              key :in, :body
              key :description, 'The properties to create a get help inquiry'
              key :required, true

              schema do
                property :inquiry do
                  property :form do
                    key :type, :string
                    key :description, 'Should conform to vets-json-schema (https://github.com/department-of-veterans-affairs/vets-json-schema)'
                  end
                end
              end
            end

            response 201 do
              key :description, 'Successful inquiry creation'
              schema do
                key :'$ref', :Asks
              end
            end

            response 501 do
              key :description, 'Feature toggled off'
            end
          end
        end
      end
    end
  end
end
