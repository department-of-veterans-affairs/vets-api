# frozen_string_literal: true

module Swagger
  module Schemas
    module Gibct
      class CalculatorConstants
        include Swagger::Blocks

        swagger_schema :GibctCalculatorConstants do
          key :required, %i[data meta links]

          property :data, type: :array, minItems: 0, uniqueItems: true do
            items do
              key :required, %i[id type attributes]

              property :id, type: :string
              property :type, type: :string
              property :attributes, type: :object do
                key :required, %i[name value]

                property :name, type: :string
                property :value, type: %i[null number string]
              end
            end
          end

          property :meta, '$ref': :GibctCalculatorConstantsMeta
          property :links, '$ref': :GibctCalculatorConstantsSelfLinks
        end

        swagger_schema :GibctCalculatorConstantsSelfLinks do
          key :type, :object
          key :required, [:self]

          property :self, type: :string
        end

        swagger_schema :GibctCalculatorConstantsMeta do
          key :type, :object
          key :required, [:version]

          property :version, type: :null
        end
      end
    end
  end
end
