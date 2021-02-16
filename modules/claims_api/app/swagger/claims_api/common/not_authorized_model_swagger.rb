# frozen_string_literal: true

module ClaimsApi
  module Common
    class NotAuthorizedModelSwagger
      include Swagger::Blocks

      swagger_component do
        schema :NotAuthorizedModel do
          property :title do
            key :type, :string
            key :example, 'Not authorized'
            key :description, 'HTTP error title'
          end

          property :detail do
            key :type, :string
            key :example, 'Not authorized'
            key :description, 'HTTP error detail'
          end

          property :code do
            key :type, :string
            key :example, 'Not authorized'
            key :description, 'HTTP error code'
          end

          property :status do
            key :type, :string
            key :example, 'Not authorized'
            key :description, 'HTTP error code'
          end
        end
      end
    end
  end
end
