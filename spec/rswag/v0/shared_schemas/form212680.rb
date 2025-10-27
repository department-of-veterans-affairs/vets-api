# frozen_string_literal: true

module Rswag
  module V0
    module SharedSchemas
      class Form212680
        FORM_212680_FULL_NAME =
          { type: 'object',
            properties: { first: { type: 'string', example: 'John', maxLength: 12 },
                          middle: { type: 'string', example: 'A', maxLength: 1, nullable: true },
                          last: { type: 'string', example: 'Doe', maxLength: 18 } } }.freeze

        FORM_212680_ADDRESS =
          { type: 'object',
            properties: { street: { type: 'string', example: '123 Main St', maxLength: 30 },
                          street2: { type: 'string', example: 'Apt 4B', maxLength: 5, nullable: true },
                          city: { type: 'string', example: 'Springfield', maxLength: 18 },
                          state: { type: 'string', example: 'IL', maxLength: 2 },
                          postalCode: { type: 'string', example: '62701', maxLength: 9 },
                          country: { type: 'string', example: 'US', maxLength: 2 } } }.freeze
      end
    end
  end
end
