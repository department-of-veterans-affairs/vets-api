# frozen_string_literal: true

module VBADocuments
  module DocumentUpload
    module V1
      class PdfUploadAttributesSwagger
        include Swagger::Blocks
        swagger_component do
          schema :PdfUploadAttributes do
            key :required, %i[total_documents total_pages content dimensions attachments]

            property :total_documents do
              key :description, 'The total number of documents contained in this upload'
              key :type, :integer
              key :example, '2'
            end

            property :total_pages do
              key :description, 'The total number of pages contained in this upload'
              key :type, :integer
              key :example, '3'
            end

            property :content do
              property :page_count do
                key :description, 'The total number of pages solely in this PDF document'
                key :type, :integer
                key :example, '1'
              end

              property :dimensions do
                key :$ref, :PdfDimensionAttributes
              end

              property :attachments do
                key :type, :array
                items do
                  property :page_count do
                    key :description, 'The number of pages in this attachment'
                    key :type, :integer
                    key :example, '2'
                  end
                  property :dimensions do
                    key :$ref, :PdfDimensionAttributes
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end
