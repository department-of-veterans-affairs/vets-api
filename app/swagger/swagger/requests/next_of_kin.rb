# frozen_string_literal: true

module Swagger::Requests
  class NextOfKin
    include Swagger::Blocks

    swagger_path '/v0/next_of_kin' do
      operation :get do
        extend Swagger::Responses::AuthenticationError

        key :summary, 'Get Next-of-Kin'
        key :description, "Returns a Veteran's Next-of-Kin"
        # key :tags, %w[]

        parameter :authorization

        response 200 do
          key :description, 'Successful request'
          schema do
            key :$ref, :NextOfKins
          end
        end
      end

      operation :post do
        extend Swagger::Responses::AuthenticationError
        extend Swagger::Responses::UnprocessableEntityError

        key :summary, 'Create Next-of-Kin'
        key :description, 'Creates a new Next-of-Kin for a Veteran'

        parameter :authorization

        parameter name: :body, in: :body do
          schema do
            property :next_of_kin, type: :object do
              key :$ref, :NextOfKin
            end
          end
        end

        response 200 do
          key :description, 'Successful request'
        end
      end
    end
  end
end
