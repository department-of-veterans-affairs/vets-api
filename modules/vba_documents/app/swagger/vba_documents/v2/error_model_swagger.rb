# frozen_string_literal: true

module VBADocuments
  module V2
    class ErrorModelSwagger
      include Swagger::Blocks

      swagger_component do
        schema :ErrorModel do
          key :description, 'Errors with some details for the given request'

          key :required, %i[status detail]
          property :status do
            key :type, :integer
            key :format, :int32
            key :example, '422'
            key :description, 'Standard HTTP Status returned with Error'
          end

          property :code do
            key :type, :integer
            key :format, :int32
            key :example, '109'
            key :description, 'Error code'
          end

          property :title do
            key :type, :string
            key :example, 'Validation error'
            key :description, 'The title of the error'
          end

          property :detail do
            key :type, :string
            key :example, 'Invalid subscription!'
            key :description, 'A more detailed message about why an error occurred'
          end
        end
      end
    end
  end
end
