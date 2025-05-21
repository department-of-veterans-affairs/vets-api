# frozen_string_literal: true

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

            parameter do
              key :name, :order_input
              key :in, :body
              key :description, 'Order input'
              key :required, true

              schema do
                key :type, :object
                key :required, [:order]

                property :use_permanent_address, type: :boolean
                property :use_temporary_address, type: :boolean
                property :additional_requests, type: :string

                property :permanent_address do
                  key :type, :object

                  property :street, type: :string
                  property :street2, type: :string
                  property :city, type: :string
                  property :state, type: :string
                  property :country, type: :string
                  property :postal_code, type: :string
                end

                property :order do
                  key :type, :array

                  items do
                    key :type, :object

                    property :product_id, type: :string
                  end
                end
              end
            end

            response 200 do
              key :description, 'mdot order response'
              schema do
                key :required, [:order]
                property :order do
                  key :type, :array
                  items do
                    key :required, %i[status order_id]
                    property :status, type: :string
                    property :product_id, type: :string
                    property :order_id, type: :string
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
