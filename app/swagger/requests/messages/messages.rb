# frozen_string_literal: true
module Swagger
  module Requests
    module Messages
      class Messages
        include Swagger::Blocks

        swagger_path '/v0/messaging/health/messages/{id}/thread' do
          operation :get do
            key :description, 'Gets the messages in a thread'
            key :operationId, 'messagesThreadIndex'
            key :tags, %w(messages)

            parameter name: :id, in: :path, required: true, type: :integer, description: 'a message id in a thread'

            response 200 do
              key :description, 'threaded messages response'

              schema do
                key :'$ref', :MessagesThread
              end
            end
          end
        end

        swagger_path '/v0/messaging/health/messages/{id}' do
          operation :get do
            key :description, 'Get the message'
            key :operationId, 'messagesShow'
            key :tags, %w(messages)

            parameter name: :id, in: :path, required: true, type: :integer, description: 'the message id'

            response 200 do
              key :description, 'message show response'

              schema do
                key :'$ref', :Message
              end
            end
          end
        end

        swagger_path '/v0/messaging/health/messages' do
          operation :post do
            key :description, 'creates a message'
            key :operationId, 'createMessages'
            key :tags, %w(messages)

            parameter name: :message, in: :body, required: true, description: 'body of message' do
              schema do
                key :'$ref', :MessageInput
              end
            end
            parameter name: :uploads, in: :body, required: false, description: 'attachments' do
              schema do
                key :'$ref', :AttachmentsInput
              end
            end

            response 200 do
              key :description, 'message attachments response'

              schema do
                key :'$ref', :Message
              end
            end
          end
        end

        swagger_path '/v0/messaging/health/messages/categories' do
          operation :get do
            key :description, 'Gets a list of message categories'
            key :operationId, 'messagesCategoriesIndex'
            key :tags, %w(messages)

            response 200 do
              key :description, 'create message categories response'

              schema do
                key :'$ref', :Categories
              end
            end
          end
        end

        swagger_path '/v0/messaging/health/messages/{message_id}/attachments/{id}' do
          operation :get do
            key :description, 'Gets a message attachment'
            key :operationId, 'messagesAttachmentShow'
            key :produces, ['application/octet-stream', 'application/pdf', 'image/png', 'image/gif', 'image/jpeg']
            key :tags, %w(messages)

            parameter name: :message_id, in: :path, required: true, type: :integer, description: 'a message id'
            parameter name: :id, in: :path, required: true, type: :integer, description: 'an attachmwnt id'

            response 200 do
              key :description, 'message attachments response'
              schema do
                key :type, :file
              end
            end
          end
        end

        swagger_path '/v0/messaging/health/messages/{id}/move' do
          operation :patch do
            key :description, 'moves a message to a new folder'
            key :operationId, 'moveMessages'
            key :tags, %w(messages)

            parameter name: :id, in: :path, required: true, type: :integer, description: 'id of the message'
            parameter name: :folder_id, in: :query, required: true, type: :integer, description: 'destination folder id'

            response 204 do
              key :description, 'message move response'
            end
          end
        end

        swagger_path '/v0/messaging/health/messages/{id}/reply' do
          operation :post do
            key :description, 'creates a message reply'
            key :operationId, 'replyMessages'
            key :tags, %w(messages)

            parameter name: :id, in: :path, required: true, type: :integer, description: 'id of the message'
            parameter name: :message, in: :body, required: true, description: 'body of message reply' do
              schema do
                key :'$ref', :MessageInput
              end
            end
            parameter name: :uploads, in: :body, required: false, description: 'attachments' do
              schema do
                key :'$ref', :AttachmentsInput
              end
            end

            response 201 do
              key :description, 'create message reply attachments response'

              schema do
                key :'$ref', :Message
              end
            end
          end
        end
      end
    end
  end
end
