# frozen_string_literal: true

module Swagger
  module Schemas
    class Notification
      include Swagger::Blocks

      swagger_schema :Notification do
        key :required, [:data]
        property :data, type: :object do
          key :required, [:attributes]
          property :attributes, type: :object do
            key :required, %i[subject read_at]
            property :subject,
                     type: :string,
                     example: 'form_10_10ez',
                     enum: ::Notification.subjects.keys.sort
            property :read_at, type: %i[string null], example: '2019-02-26T21:20:50.151Z'
          end
        end
      end
    end
  end
end
