# frozen_string_literal: true

module ClaimsApi
  module Common
    class UnprocessableEntitySwagger
      include Swagger::Blocks

      swagger_component do
        schema :UnprocessableEntityModel do
          property :status do
            key :type, :string
            key :example, '422'
            key :description, 'HTTP error code'
          end

          property :detail do
            key :type, :string
            key :example, 'Unprocessable Entity'
            key :description, 'HTTP error detail'
          end
        end
      end
    end
  end
end
