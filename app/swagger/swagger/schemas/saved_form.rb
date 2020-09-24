# frozen_string_literal: true

module Swagger
  module Schemas
    class SavedForm
      include Swagger::Blocks
      swagger_schema :SavedForm do
        key :required, [:data]

        property :data, type: :object do
          property :id, type: :string
          property :type, type: :string

          property :attributes, type: :object do
            property :form, type: :string
            property :submitted_at, type: :string
            property :regional_office, type: :array
            property :confirmation_number, type: :string
          end
        end
      end
    end
  end
end
