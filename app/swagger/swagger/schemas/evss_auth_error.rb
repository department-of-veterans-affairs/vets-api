# frozen_string_literal: true

# rubocop:disable Layout/LineLength
module Swagger
  module Schemas
    class EVSSAuthError
      include Swagger::Blocks

      swagger_schema :EVSSAuthError do
        key :required, [:errors]

        property :errors do
          key :type, :array
          items do
            key :required, %i[title detail code status]
            property :title, type: :string, example: 'Forbidden'
            property :detail,
                     type: :string,
                     example: 'User does not have access to the requested resource due to missing values: corp_id, edipi'
            property :code, type: :string, example: '403'
            property :status, type: :string, example: '403'
          end
        end
      end
    end
  end
end
# rubocop:enable Layout/LineLength
