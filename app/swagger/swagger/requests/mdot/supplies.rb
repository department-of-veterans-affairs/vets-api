# frozen_string_literal: true

# app/controllers/v0/mdot/suppliesc_controller.rb
module Swagger
  module Requests
    module MDOT
      class Supplies
        include Swagger::Blocks

        swagger_path '/v0/mdot/supplies' do
          operation :post do
            key :summary, 'Order supplies'
            key :description, 'Place an order for medical supplies'
            key :operationId, 'orderSupplies'
            key :tags, %w[ mdot]

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

                property :use_permanent_address, type: :boolean, example: true
                property :use_temporary_address, type: :boolean, example: false
                property :vet_email, type: :string, example: "vet1@va.gov"
                property :order do
                  key :type, :array

                  items do
                    key :type, :object
                    property :productId, type: :integer, example: 2499
                  end
                end

                property :permanent_address do
                  key :type, :object
                  property :isMilitary, type: :boolean, example: false
                  property :street, type: :string, example: "125 SOME RD"
                  property :street2, type: :string, example: "APT 101"
                  property :city, type: :string, example: "DENVER"
                  property :state, type: :string, example: "CO"
                  property :country, type: :string, example: "United States"
                  property :postalCode, type: :string, example: "11111"
                end

                property :temporary_address do
                  key :type, :object
                  property :isMilitary, type: :boolean, example: false
                  property :street, type: :string, example: "17250 w colfax ave"
                  property :street2, type: :string, example: "a-204"
                  property :city, type: :string, example: "Golden"
                  property :state, type: :string, example: "CO"
                  property :country, type: :string, example: "United States"
                  property :postalCode, type: :string, example: "80401"
                end
              end
            end

            response 200 do
              key :description, 'Response is OK'
              schema do
                key :type, :array
                items do
                  key :type, :object
                  property :productId, type: :integer, example: 2499
                  property :orderID, type: :integer, example: 10001
                  property :status, type: :string, example: 'Order Processed', enum: %w[Order\ Processed Order\ Pending Unable\ to\ order\ item\ since\ the\ last\ order\ was\ less\ than\ 5\ months\ ago.]
                end
              end
            end
          end
        end
      end
    end
  end
end
