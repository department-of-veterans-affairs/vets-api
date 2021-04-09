# frozen_string_literal: true

module Swagger
  module Requests
    module ContactUs
      class InquiriesList
        include Swagger::Blocks

        swagger_path '/v0/contact_us/inquiries' do
          operation :get do
            extend Swagger::Responses::AuthenticationError

            key :description, 'Get a list of inquiries sent by user'
            key :operationId, 'getInquiries'
            key :tags, %w[contact_us]

            parameter :authorization

            response 200 do
              key :description, 'Response is OK'
              schema do
                key :$ref, :InquiriesList
              end
            end
          end
        end
      end
    end
  end
end
