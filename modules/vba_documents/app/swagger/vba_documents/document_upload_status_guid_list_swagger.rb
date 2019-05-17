# frozen_string_literal: true

module VbaDocuments
  class DocumentUploadStatusGuidListSwagger
    include Swagger::Blocks
    swagger_schema :DocumentUploadStatusGuidList do
      key :name, 'content'
      key :type, :object
      key :description, 'List of GUIDs for which to retrieve current status.'
      key :required, %i[ids]

      property :ids do
        key :description, 'List of IDs for previous document upload submissions'
        key :type, :array
        items do
          key :type, :string
          key :format, :uuid
          key :example, '6d8433c1-cd55-4c24-affd-f592287a7572'
        end
        key :minItems, 1
        key :maxItems, 100
      end
    end
  end
end
