# frozen_string_literal: true

module VAOS
  module Schemas
    class CCSupportedSites
      include Swagger::Blocks

      swagger_schema :CCSupportedSites do
        key :required, %i[data meta]

        property :data, type: :array do
          items do
            key :id, type: :string
            key :type, type: :string
            key :attributes, type: :object do
              key :'$ref', :CCSupportedSite
            end
          end
        end

        property :meta, type: :object do
          key :'$ref', :Pagination
        end
      end

      swagger_schema :CCSupportedSite do
        key :required, %i[id name timezone objectType link]

        property :id, type: :string
        property :name, type: :string
        property :timezone, type: :string
        property :objectType, type: :string
        property :link, type: :array do
        end
      end
    end
  end
end
