# frozen_string_literal: true

module Swagger
  module Schemas
    module Health
      class Messages
        include Swagger::Blocks

        swagger_schema :Messages do
          key :required, %i[data meta]

          property :data, type: :array, minItems: 1, uniqueItems: true do
            items do
              key :'$ref', :DataAttributes
            end
          end

          property :meta, '$ref': :MetaSortPagination
          property :links, '$ref': :LinksAll
        end

        swagger_schema :MessagesThread do
          key :required, [:data]

          property :data, type: :array, minItems: 1, uniqueItems: true do
            items do
              key :'$ref', :DataAttributes
            end
          end

          property :meta, '$ref': :MetaSortPagination
          property :links, '$ref': :LinksAll
        end

        swagger_schema :Message do
          key :required, [:data]
          property :data, type: :object, '$ref': :DataAttributesWithRelationships
          property :included, '$ref': :Included
        end

        swagger_schema :Included do
          key :required, [:included]

          property :included, type: :array, minItems: 0, uniqueItems: true do
            items do
              key :required, %i[id type attributes links]

              property :id, type: :string
              property :type, type: :string, enum: [:attachments]
              property :attributes, type: :object do
                key :required, %i[message_id name]

                property :message_id, type: :integer
                property :name, type: :string
              end
              property :links, '$ref': :LinksDownload
            end
          end
        end

        swagger_schema :DataAttributes do
          key :type, :object
          key :required, %i[id type attributes links]

          property :id, type: :string
          property :type, type: :string, enum: %i[messages message_drafts]
          property :attributes, '$ref': :MessageAttributes
          property :links, '$ref': :LinksSelf
        end

        swagger_schema :DataAttributesWithRelationships do
          key :type, :object
          key :required, %i[id type attributes relationships links]

          property :id, type: :string
          property :type, type: :string, enum: %i[messages message_drafts]
          property :attributes, '$ref': :MessageAttributes
          property :relationships, '$ref': :Relationships
          property :links, '$ref': :LinksSelf
        end

        swagger_schema :MessageAttributes do
          key :type, :object
          key :required, %i[message_id category subject body attachment sent_date sender_id
sender_name recipient_id recipient_name read_receipt]

          property :message_id, type: :integer
          property :category, type: :string
          property :subject, type: :string
          property :body, type: %i[null string]
          property :attachment, type: :boolean
          property :sent_date, type: %i[null string]
          property :sender_id, type: :integer
          property :sender_name, type: :string
          property :recipient_id, type: :integer
          property :recipient_name, type: :string
          property :read_receipt, type: %i[null string]
        end

        swagger_schema :Relationships do
          key :type, :object
          key :required, [:attachments]

          property :attachments, type: :object do
            key :required, [:data]

            property :data, type: :array, minItems: 0, uniqueItems: true do
              items do
                key :required, %i[id type]

                property :id, type: :string
                property :type, type: :string, enum: [:attachments]
              end
            end
          end
        end

        swagger_schema :Categories do
          key :required, [:data]

          property :data, type: :object do
            key :required, %i[id type attributes]

            property :id, type: :string
            property :type, type: :string, enum: [:categories]
            property :attributes, type: :object do
              key :required, [:message_category_type]

              property :message_category_type, type: :array, minItems: 1, uniqueItems: true do
                items do
                  key :type, :string
                end
              end
            end
          end
        end

        swagger_schema :MessageInput do
          key :type, :object
          key :required, %i[subject category recipient_id body]

          property :draft_id, type: :integer
          property :subject, type: :string
          property :category, type: :string
          property :recipient_id, type: :integer
          property :body, type: :string
        end

        swagger_schema :AttachmentsInput do
          key :type, :array
        end
      end
    end
  end
end
