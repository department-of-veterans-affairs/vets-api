# frozen_string_literal: true

module VbaDocuments
  module DocumentUpload
    class StatusGuidListSwagger
      include Swagger::Blocks
      swagger_schema :DocumentUploadStatusGuidList do
        key :type, :object
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
          key :maxItems, 1000
        end
      end
    end
  end
end
