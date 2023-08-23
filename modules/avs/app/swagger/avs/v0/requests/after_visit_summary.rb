# frozen_string_literal: true

module Avs
  class V0::Requests::AfterVisitSummary
    include Swagger::Blocks

    swagger_path '/avs/v0/avs/{id}' do
      operation :get do
        extend Swagger::Responses::AuthenticationError

        key :description, 'Returns the After Visit Summary for the given id'

        parameter :authorization

        parameter do
          key :name, :id
          key :description, 'After Visit Summary ID'
          key :in, :path
          key :type, :string
          key :required, true
        end
        response 200 do
          key :description, 'Response is OK'
          schema do
            key :$ref, :Avs
          end
        end
      end
    end
  end
end
