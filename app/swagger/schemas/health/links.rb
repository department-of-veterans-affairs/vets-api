# frozen_string_literal: true

module Swagger
  module Schemas
    module Health
      class Links
        include Swagger::Blocks

        swagger_schema :LinksAll do
          key :type, :object
          key :required, [:self, :first, :prev, :next, :last]

          property :self, type: :string
          property :first, type: :string
          property :prev, type: [:string, :null]
          property :next, type: [:string, :null]
          property :last, type: :string
        end

        swagger_schema :LinksSelf do
          key :type, :object
          key :required, [:self]

          property :self, type: :string
        end
      end
    end
  end
end
