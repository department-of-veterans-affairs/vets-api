# frozen_string_literal: true
module Swagger
  module Requests
    module Messages
      class Folders
        include Swagger::Blocks

        swagger_path '/v0/messaging/health/folders' do
          operation :get do
            key :description, 'Get a list of folders'
            key :operationId, 'foldersIndex'
            key :tags, %w(folders)

            parameter :optional_page_number
            parameter :optional_page_length

            response 200 do
              key :description, 'folders response'

              schema do
                key :'$ref', :Folders
              end
            end
          end
        end

        swagger_path '/v0/messaging/health/folders/{folder_id}/messages' do
          operation :get do
            key :description, 'Get a list of messages in a specific folder'
            key :operationId, 'foldersMessageIndex'
            key :tags, %w(folders)

            parameter name: :folder_id, in: :path, required: true, type: :integer, description: 'id of the folder'
            parameter :optional_page_number
            parameter :optional_page_length

            response 200 do
              key :description, 'folder messages response'

              schema do
                key :'$ref', :Messages
              end
            end
          end
        end
      end
    end
  end
end
