# frozen_string_literal: true

module Openapi
  module Schemas
    class Name
      FIRST_MIDDLE_LAST =
        { type: 'object',
          properties: { first: { type: 'string', example: 'John', maxLength: 12 },
                        middle: { type: 'string', example: 'A', maxLength: 1, nullable: true },
                        last: { type: 'string', example: 'Doe', maxLength: 18 } } }.freeze
    end
  end
end

