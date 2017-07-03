# frozen_string_literal: true

module Swagger
  module Schemas
    module Evss
      class Common
        include Swagger::Blocks

        swagger_schema :Meta do
          key :description, 'The response from the EVSS service to vets-api'
          key :required, [:status]
          property :status, type: :string, enum: %w(OK NOT_FOUND SERVER_ERROR NOT_AUTHORIZED)
        end
      end
    end
  end
end
