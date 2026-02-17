# frozen_string_literal: true

module VBADocuments
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
            key :example, 'DOC104 - Upload rejected by upstream system. Processing failed and upload must be resubmitted'
            key :description, 'A more detailed message about why an error occurred'
          end
        end

        schema :UploadsReportBadRequestErrorModel do
          key :description, 'Validation error for uploads/report request payload'

          key :required, %i[title detail code status]

          property :title do
            key :type, :string
            key :example, 'Too many items submitted'
          end

          property :detail do
            key :type, :string
            key :example, '"ids" cannot exceed 1000 items (submitted 1001)'
          end

          property :code do
            key :type, :string
            key :example, '108'
          end

          property :status do
            key :type, :string
            key :example, '400'
          end
        end
      end
    end
  end
end
