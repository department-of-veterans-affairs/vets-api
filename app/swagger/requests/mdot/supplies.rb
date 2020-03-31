module Swagger
  module Requests
    module MDOT
      class Supplies
        include Swagger::Blocks

        swagger_path '/v0/mdot/supplies' do
          operation :post do
            key :description, 'Create a MDOT supply order'
            key :operationId, 'addMdotOrder'
            key :tags, %w[mdot]

            extend Swagger::Responses::AuthenticationError
            parameter :authorization

            key :produces, ['application/json']
            key :consumes, ['application/json']

            response 200 do
              key :description, 'mdot order response'

              schema do
                key :required, %i[status order_id]

                property :status, type: :string
                property :order_id, type: :string
              end
            end
          end
        end
      end
    end
  end
end
