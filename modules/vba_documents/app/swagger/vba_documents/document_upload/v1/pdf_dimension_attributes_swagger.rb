# frozen_string_literal: true

module VBADocuments
  module DocumentUpload
    module V1
      class PdfDimensionAttributesSwagger
        include Swagger::Blocks
        swagger_component do
          schema :PdfDimensionAttributes do
            key :required, %i[height width oversized_pdf]

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
            property :oversized_pdf do
              key :description, 'Indicates if this is an oversized PDF (greater than 78x101)'
              key :type, :boolean
              key :example, 'false'
            end
          end
        end
      end
    end
  end
end
