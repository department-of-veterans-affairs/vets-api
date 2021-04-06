# frozen_string_literal: true

module ClaimsApi
  module Common
    class NotFoundSwagger
      include Swagger::Blocks

      swagger_component do
        schema :NotFoundModel do
          property :title do
            key :type, :string
            key :example, 'Resource not found'
            key :description, 'Error Title'
          end

          property :detail do
            key :type, :string
            key :example, 'Resource not found'
            key :description, 'HTTP error detail'
          end

          property :code do
            key :type, :string
            key :example, '404'
            key :description, 'HTTP error code'
          end

          property :status do
            key :type, :string
            key :example, '404'
            key :description, 'HTTP error code'
          end
        end

        schema :ClaimsNotFoundModel do
          property :title do
            key :type, :string
            key :example, 'Resource not found'
            key :description, 'Error Title'
          end

          property :detail do
            key :type, :string
            key :example, 'Claims not found'
            key :description, 'HTTP error detail'
          end

          property :code do
            key :type, :string
            key :example, '404'
            key :description, 'HTTP error code'
          end

          property :status do
            key :type, :string
            key :example, '404'
            key :description, 'HTTP error code'
          end
        end

        schema :ClaimNotFoundModel do
          property :title do
            key :type, :string
            key :example, 'Resource not found'
            key :description, 'Error Title'
          end

          property :detail do
            key :type, :string
            key :example, 'Claim not found'
            key :description, 'HTTP error detail'
          end

          property :code do
            key :type, :string
            key :example, '404'
            key :description, 'HTTP error code'
          end

          property :status do
            key :type, :string
            key :example, '404'
            key :description, 'HTTP error code'
          end
        end
      end
    end
  end
end
