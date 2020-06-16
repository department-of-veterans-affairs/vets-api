# frozen_string_literal: true

module Swagger
  module Schemas
    class Email
      include Swagger::Blocks

      swagger_schema :Email do
        key :required, [:data]

        property :data, type: :object do
          key :required, [:attributes]
          property :attributes, type: :object do
            property :email, type: :string, example: 'john@example.com'
            property :effective_at, type: :string, example: '2018-02-27T14:41:32.283Z'
          end
        end
      end
    end
  end
end
