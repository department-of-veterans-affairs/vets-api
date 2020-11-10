# frozen_string_literal: true

module Swagger
  module Schemas
    class Asks
      include Swagger::Blocks

      swagger_schema :Asks do
        key :required, %i[confirmationNumber dateSubmitted]
        property :confirmationNumber,
                 type: :string,
                 example: '0000-0000-0000'
        property :dateSubmitted,
                 type: :string,
                 example: '11-03-2020'
      end
    end
  end
end
