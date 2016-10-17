# frozen_string_literal: true
require 'common/models/collection'

module SM
  module API
    module Folders
      MHV_MAXIMUM_PER_PAGE = 250

      def get_folders
        json = perform(:get, 'folder', nil, token_headers).body
        Common::Collection.new(Folder, json)
      end

      # get_folder: Retrieves a folder by its id.
      def get_folder(id)
        json = perform(:get, "folder/#{id}", nil, token_headers).body
        Folder.new(json)
      end

      # post_create_folder: Creates a folder.
      def post_create_folder(name)
        json = perform(:post, 'folder', %({ "name":"#{name}" }), token_headers).body
        Folder.new(json)
      end

      ## delete_folder: Deletes a folder.
      def delete_folder(id)
        response = perform(:delete, "folder/#{id}", nil, token_headers)
        response.nil? ? nil : response.status
      end

      def get_folder_messages(folder_id)
        page = 1
        json = { data: [], errors: {}, metadata: {} }

        loop do
          path = "folder/#{folder_id}/message/page/#{page}/pageSize/#{MHV_MAXIMUM_PER_PAGE}"
          page_data = perform(:get, path, nil, token_headers).body
          json[:data].concat(page_data[:data])
          json[:metadata].merge(page_data[:metadata])
          break unless page_data[:data].size == MHV_MAXIMUM_PER_PAGE
          page += 1
        end

        Common::Collection.new(Message, json)
      end
    end
  end
end
