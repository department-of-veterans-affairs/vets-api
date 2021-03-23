# frozen_string_literal: true

module Swagger
  module Requests
    module ContactUs
      class Inquiries
        include Swagger::Blocks

        swagger_path '/v0/contact_us/inquiries' do
          operation :post do
            extend Swagger::Responses::ValidationError

            key :description, 'Create an inquiry'
            key :operationId, 'createsAnInquiry'
            key :tags, %w[contact_us]

            parameter :optional_authorization

            parameter do
              key :name, :body
              key :in, :body
              key :description, 'The properties to create an inquiry'
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
                key :'$ref', :SuccessfulInquiryCreation
              end
            end

            response 501 do
              key :description, 'Feature toggled off'
            end
          end

          operation :get do
            extend Swagger::Responses::AuthenticationError

            key :description, 'Get a list of inquiries sent by user'
            key :operationId, 'getInquiries'
            key :tags, %w[contact_us]

            parameter :authorization

            response 200 do
              key :description, 'Response is OK'
              schema do
                key :'$ref', :InquiriesList
              end
            end
          end
        end
      end
    end
  end
end
