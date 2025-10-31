# frozen_string_literal: true

module Openapi
  module Components
    class Name
      FIRST_MIDDLE_LAST =
        { type: 'object',
          required: %w[first last],
          properties: { first: { type: 'string', example: 'John', maxLength: 12 },
                        middle: { type: 'string', example: 'A', maxLength: 1 },
                        last: { type: 'string', example: 'Doe', maxLength: 18 } } }.freeze
    end
  end
end
