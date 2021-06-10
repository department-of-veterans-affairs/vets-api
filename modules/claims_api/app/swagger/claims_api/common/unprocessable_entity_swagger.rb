# frozen_string_literal: true

module ClaimsApi
  module Common
    class UnprocessableEntitySwagger
      include Swagger::Blocks

      swagger_component do
        schema :UnprocessableEntityModel do
          property :title do
            key :type, :string
            key :example, 'Unprocessable Entity'
            key :description, 'Error Title'
          end

          property :detail do
            key :type, :string
            key :example, 'Unprocessable Entity'
            key :description, 'HTTP error detail'
          end

          property :code do
            key :type, :string
            key :example, '422'
            key :description, 'HTTP error code'
          end

          property :status do
            key :type, :string
            key :example, '422'
            key :description, 'HTTP error code'
          end
        end
      end
    end
  end
end
