# frozen_string_literal: true
module Swagger
  module Schemas
    class Address
      include Swagger::Blocks

      swagger_schema :Address do
        key :required, [:data]

        property :data, type: :object do
          key :required, [:attributes]
          property :attributes, type: :object do
            property :type, type: :string, enum:
              %w(
                DOMESTIC
                INTERNATIONAL
                MILITARY
              ), example: 'DOMESTIC'
            property :address_effective_date, type: :string, example: '1973-01-01T05:00:00.000+00:00'
            property :address_one, type: :string, example: '140 Rock Creek Church Rd NW'
            property :address_two, type: :string, example: ''
            property :address_three, type: :string, example: ''
            property :city, type: :string, example: 'Washington'
            property :state_code, type: :string, example: 'DC'
            property :zip_code, type: :string, example: '20011'
            property :zip_suffix, type: :string, example: '1865'
          end
        end
      end
    end
  end
end
