# frozen_string_literal: true

module Openapi
  module Components
    class Address
      SIMPLE_ADDRESS =
        { type: 'object',
          required: %w[street city state postalCode country],
          properties: { street: { type: 'string', example: '123 Main St', maxLength: 30 },
                        street2: { type: 'string', example: '4B', maxLength: 30 },
                        city: { type: 'string', example: 'Springfield', maxLength: 18 },
                        state: { type: 'string', example: 'IL', maxLength: 2 },
                        postalCode: { type: 'string', example: '62701', maxLength: 9 },
                        country: { type: 'string', example: 'US', maxLength: 2 } } }.freeze
    end
  end
end
