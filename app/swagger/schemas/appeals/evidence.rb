# frozen_string_literal: true

module Swagger
  module Schemas
    module Appeals
      class Evidence
        include Swagger::Blocks

        swagger_schema :Evidence do
          property :description, type: :string, example: ''
          property :date, type: :string, example: ''
        end
      end
    end
  end
end
