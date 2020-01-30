# frozen_string_literal: true

module VaForms
  module Common
    class FormsErrorModelSwagger
      include Swagger::Blocks

      swagger_component do
        schema :FormsErrorModel do
          key :description, 'Errors with some details for the given request'

          key :required, %i[status details]
          property :status do
            key :type, :integer
            key :format, :int32
            key :example, '422'
            key :description, 'Standard HTTP Status returned with Error'
          end

          property :source do
            key :type, :string
            key :example, '#/query_something'
            key :description, 'a JSON Pointer to the offending attribute in the payload'
          end

          property :details do
            key :type, :string
            key :example, 'Your search parameter is not currently support'
            key :description, 'A more detailed message about why an error occured'
          end
        end
      end
    end
  end
end
