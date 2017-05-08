# frozen_string_literal: true
module Swagger
  module Requests
    module Messages
      class Messages
        include Swagger::Blocks

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

        swagger_path '/v0/messaging/health/messages/categories' do
          operation :get do
            key :description, 'Gets a list of message categories'
            key :operationId, 'messagesCategoriesIndex'
            key :tags, %w(messages)

            response 200 do
              key :description, 'message categories response'

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
              key :description, 'message categories response'

              schema do
                key :type, :file
              end
            end
          end
        end
      end
    end
  end
end
