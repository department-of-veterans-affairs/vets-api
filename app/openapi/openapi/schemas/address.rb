# frozen_string_literal: true

module Openapi
  module Schemas
    class Address
      SIMPLE_ADDRESS =
        { type: 'object',
          properties: { street: { type: 'string', example: '123 Main St', maxLength: 30 },
                        street2: { type: 'string', example: 'Apt 4B', maxLength: 30, nullable: true },
                        city: { type: 'string', example: 'Springfield', maxLength: 18 },
                        state: { type: 'string', example: 'IL', maxLength: 2 },
                        postalCode: { type: 'string', example: '62701', maxLength: 9 },
                        country: { type: 'string', example: 'US', maxLength: 2 } } }.freeze
    end
  end
end
