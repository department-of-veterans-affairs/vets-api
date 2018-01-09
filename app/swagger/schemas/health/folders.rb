# frozen_string_literal: true

module Swagger
  module Schemas
    module Health
      class Folders
        include Swagger::Blocks

        swagger_schema :Folders do
          key :required, [:data, :meta]

          property :data, type: :array, minItems: 1, uniqueItems: true do
            items do
              key :'$ref', :FolderBase
            end
          end

          property :meta, '$ref': :MetaPagination
          property :links, '$ref': :LinksAll
        end

        swagger_schema :Folder do
          key :required, [:data]

          property :data, type: :object, '$ref': :FolderBase
        end

        swagger_schema :FolderBase do
          key :required, [:id, :type, :attributes, :links]

          property :id, type: :string
          property :type, type: :string, enum: [:folders]

          property :attributes, type: :object do
            key :'$ref', :FolderAttributes
          end

          property :links, '$ref': :LinksSelf
        end

        swagger_schema :FolderAttributes do
          key :required, [:folder_id, :name, :count, :unread_count, :system_folder]

          property :folder_id, type: :integer
          property :name, type: :string
          property :count, type: :integer
          property :unread_count, type: :integer
          property :system_folder, type: :boolean
        end
      end
    end
  end
end
