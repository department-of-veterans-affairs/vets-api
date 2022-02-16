# frozen_string_literal: true

module Swagger
  module Schemas
    class OnsiteNotifications
      include Swagger::Blocks

      swagger_schema :OnsiteNotification do
        key :type, :object

        property(:id, type: :string)
        property(:type, type: :string)

        property(:attributes) do
          key :type, :object

          property(:template_id, type: :string)
          property(:va_profile_id, type: :string)
          property(:dismissed, type: :boolean)
          property(:created_at, type: :string)
          property(:updated_at, type: :string)
        end
      end
    end
  end
end
