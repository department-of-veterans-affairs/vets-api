# frozen_string_literal: true
module Swagger
  module Requests
    module Messages
      class MessageDrafts
        include Swagger::Blocks

        swagger_path '/v0/messaging/health/message_drafts' do
          operation :post do
            key :description, 'creates a message draft'
            key :operationId, 'messageDraftsCreate'
            key :tags, %w(messages)

            parameter name: :message_draft, in: :body, required: true, description: 'body of reply draft message' do
              schema do
                key :'$ref', :MessageInput
              end
            end

            response 201 do
              key :description, 'create reply message response'

              schema do
                key :'$ref', :Message
              end
            end
          end
        end

        swagger_path '/v0/messaging/health/message_drafts/{reply_id}/replydraft' do
          operation :post do
            key :description, 'creates a reply message draft'
            key :operationId, 'messageDraftsReplyCreate'
            key :tags, %w(messages)

            parameter name: :reply_id, in: :path, type: :integer, required: true, description: 'message replied to id'
            parameter name: :message_draft, in: :body, required: true, description: 'body of reply draft message' do
              schema do
                key :'$ref', :MessageInput
              end
            end

            response 201 do
              key :description, 'create reply message response'

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
