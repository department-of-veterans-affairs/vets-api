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

            response 404 do
              key :description, 'folder show messages response error'

              schema do
                key :'$ref', :Errors
              end
            end
          end
        end

        swagger_path '/v0/messaging/health/folders/{id}' do
          operation :get do
            key :description, 'Get information about a specific folder'
            key :operationId, 'foldersShow'
            key :tags, %w(folders)

            parameter name: :id, in: :path, required: true, type: :integer, description: 'id of the folder'

            response 200 do
              key :description, 'folder show response'

              schema do
                key :'$ref', :Folder
              end
            end

            response 404 do
              key :description, 'folder show response error'

              schema do
                key :'$ref', :Errors
              end
            end
          end
        end

        swagger_path '/v0/messaging/health/folders' do
          operation :post do
            key :description, 'Create a new folder'
            key :operationId, 'foldersCreate'
            key :tags, %w(folders)

            parameter name: :folder, in: :body, required: true, description: 'new folder name' do
              schema do
                key :type, :object
                property :name, type: :string
              end
            end

            response 201 do
              key :description, 'create folder response'

              schema do
                key :'$ref', :Folder
              end
            end
          end
        end

        swagger_path '/v0/messaging/health/folders/{id}' do
          operation :delete do
            key :description, 'Deletes a specific folder'
            key :operationId, 'foldersDelete'
            key :tags, %w(folders)

            parameter name: :id, in: :path, required: true, type: :integer, description: 'id of the folder'

            response 204 do
              key :description, 'delete folder response'
            end

            response 404 do
              key :description, 'folder delete response error'

              schema do
                key :'$ref', :Errors
              end
            end
          end
        end
      end
    end
  end
end
