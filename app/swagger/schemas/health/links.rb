# frozen_string_literal: true

module Swagger
  module Schemas
    module Health
      class Links
        include Swagger::Blocks

        swagger_schema :LinksAll do
          key :type, :object
          key :required, [:self, :first, :prev, :next, :last]

          property :self, type: :string
          property :first, type: :string
          property :prev, type: [:string, :null]
          property :next, type: [:string, :null]
          property :last, type: :string
        end

        swagger_schema :LinksSelf do
          key :type, :object
          key :required, [:self]

          property :self, type: :string
        end

        swagger_schema :LinksDownload do
          key :type, :object
          key :required, [:download]

          property :download, type: :string
        end

        swagger_schema :LinksTracking do
          key :type, :object
          key :required, [:self, :prescription, :tracking_url]

          property :self, type: :string
          property :prescription, type: :string
          property :tracking_url, type: :string
        end
      end
    end
  end
end
