# frozen_string_literal: true

module Swagger
  module Schemas
    module Appeals
      class Issue
        include Swagger::Blocks

        swagger_schema :Issue do
          property :active, type: :boolean, example: 'TODO'
          property :description, type: :string, example: 'TODO'
          property :diagnostic_code, type: [:string, :null], example: 'TODO'
          property :last_action, type: :string, enum: %w(field_grant withdrawn allowed denied remand cavc_remand), example: 'TODO'
          property :date, type: [:string, :null], example: 'TODO'
        end
      end
    end
  end
end
