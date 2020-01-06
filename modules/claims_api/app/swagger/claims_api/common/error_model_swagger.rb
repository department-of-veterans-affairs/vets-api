# frozen_string_literal: true

module ClaimsApi
  module Common
    class ErrorModelSwagger
      include Swagger::Blocks

      swagger_component do
        schema :ErrorModel do
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
            key :example, '#/serviceInformation/servicePeriods/1/serviceBranch'
            key :description, 'a JSON Pointer to the offending attribute in the payload'
          end

          property :details do
            key :type, :string
            key :example, 'burial is not currently supported, but will be in a future version'
            key :description, 'A more detailed message about why an error occured'
          end
        end
      end
    end
  end
end
