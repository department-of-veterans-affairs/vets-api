# frozen_string_literal: true

module Swagger
  module Schemas
    module MDOT
      class Supplies
        include Swagger::Blocks

        swagger_schema :Supplies do
          key :required, %i[supplies veteran_address]
          property :supplies, type: :array do
            items do
              key :required, %i[product_name product_group product_id quantity]
              property :device_name, type: :string
              property :last_order_date, type: :string, format: :date
              property :next_availability_date, type: :string, format: :date
              property :product_name, type: :string
              property :product_group, type: :string
              property :product_id, type: :string
              property :quantity, type: :integer
            end
          end
          property :veteran_address do
            key :'$ref', :VeteranAddress
          end
          property :veteran_temporary_address do
            key :'$ref', :VeteranAddress
          end
        end

        swagger_schema :VeteranAddress do
          key :required, %i[street city state country postal_code]
          property :street, type: :string
          property :street2, type: :string
          property :city, type: :string
          property :state, type: :string
          property :country, type: :string
          property :postal_code, type: :string
        end
      end
    end
  end
end
