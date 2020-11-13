# frozen_string_literal: true

module VbaDocuments
  module DocumentUpload
    module V1
      class PdfDimensionAttributesSwagger
        include Swagger::Blocks
        swagger_component do
          schema :PdfDimensionAttributes do
            key :required, %i[height width]

            property :height do
              key :description, 'The document height'
              key :type, :integer
              key :example, '11.0'
            end
            property :width do
              key :description, 'The document width'
              key :type, :integer
              key :example, '8.5'
            end
          end
        end
      end
    end
  end
end
