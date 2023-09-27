# frozen_string_literal: true

module Swagger::Requests
  class NextOfKin
    include Swagger::Blocks

    swagger_path '/v0/next_of_kin' do
      operation :get do
        extend Swagger::Responses::AuthenticationError

        key :summary, 'Get Next-of-Kin'
        key :description, "Returns a Veteran's Next-of-Kin"
        key :tags, [:next_of_kin]

        parameter :authorization

        response 200 do
          key :description, 'Successful request'
          schema do
            key :$ref, :NextOfKins
          end
        end
      end
    end
  end
end
