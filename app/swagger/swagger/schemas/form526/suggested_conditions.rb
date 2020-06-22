# frozen_string_literal: true

module Swagger
  module Schemas
    module Form526
      class SuggestedConditions
        include Swagger::Blocks

        swagger_schema :SuggestedConditions do
          key :required, [:data]

          property :data do
            key :type, :array
            items do
              key :'$ref', :DisabilityContention
            end
          end
        end

        swagger_schema :DisabilityContention do
          key :required, %i[id type attributes]

          property :id, type: :string
          property :type, type: :string

          property :attributes, type: :object do
            property :code, type: :integer, example: 460
            property :medical_term, type: :string, example: 'arteriosclerosis'
            property :lay_term, type: :string, example: 'hardened arteries'
          end
        end
      end
    end
  end
end
