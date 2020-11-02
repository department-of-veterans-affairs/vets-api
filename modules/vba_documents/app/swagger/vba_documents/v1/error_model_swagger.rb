# frozen_string_literal: true

module VbaDocuments
  module V1
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

          property :detail do
            key :type, :string
            key :example, 'DOC104 - Upload rejected by upstream system.'
            key :description, 'A more detailed message about why an error occurred'
          end
        end
      end
    end
  end
end
