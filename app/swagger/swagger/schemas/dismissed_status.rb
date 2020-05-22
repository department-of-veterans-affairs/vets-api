# frozen_string_literal: true

module Swagger
  module Schemas
    class DismissedStatus
      include Swagger::Blocks

      swagger_schema :DismissedStatus do
        key :required, [:data]
        property :data, type: :object do
          key :required, [:attributes]
          property :attributes, type: :object do
            key :required, %i[subject status read_at]
            property :subject,
                     type: :string,
                     example: 'form_10_10ez',
                     enum: Notification.subjects.keys.sort
            property :status,
                     type: :string,
                     example: 'pending_mt',
                     enum: Notification.statuses.keys.sort
            property :status_effective_at, type: :string, example: '2019-02-25T01:22:00.000Z'
            property :read_at, type: :string, example: '2019-02-26T21:20:50.151Z'
          end
        end
      end
    end
  end
end
