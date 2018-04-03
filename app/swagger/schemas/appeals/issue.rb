# frozen_string_literal: true

module Swagger
  module Schemas
    module Appeals
      class Issue
        include Swagger::Blocks

        swagger_schema :Issue do
          property :active, type: :boolean, example: true
          property :description, type: :string, example: 'Increased rating, migraines'
          property :diagnostic_code, type: %w[string null], example: '8100'
          property :last_action, type: %w[string null], enum: [
            'field_grant', 'withdrawn', 'allowed', 'denied', 'remand', 'cavc_remand', nil
          ], example: 'remand'
          property :date, type: %i[string null], example: '2016-05-03'
        end
      end
    end
  end
end
