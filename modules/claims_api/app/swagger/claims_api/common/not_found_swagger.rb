# frozen_string_literal: true

module ClaimsApi
  module Common
    class NotFoundSwagger
      include Swagger::Blocks

      swagger_component do
        schema :NotFoundModel do
          property :status do
            key :type, :string
            key :example, '404'
            key :description, 'HTTP error code'
          end

          property :detail do
            key :type, :string
            key :example, 'Resource not found'
            key :description, 'HTTP error detail'
          end
        end
      end
    end
  end
end
