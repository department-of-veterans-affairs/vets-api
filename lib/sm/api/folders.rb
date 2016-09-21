# frozen_string_literal: true
require 'common/models/collection'

module SM
  module API
    module Folders
      MHV_MAXIMUM_PER_PAGE = 250

      def get_folders
        json = perform(:get, 'folder', nil, token_headers)
        collection = Common::Collection.new(Folder, json)
      end

      # get_folder: Retrieves a folder by its id.
      def get_folder(id)
        json = perform(:get, "folder/#{id}", nil, token_headers)
        Folder.new(json)
      end

      # post_create_folder: Creates a folder.
      def post_create_folder(name)
        json = perform(:post, 'folder', %({ "name":"#{name}" }), token_headers)
        Folder.new(json)
      end

      ## delete_folder: Deletes a folder.
      def delete_folder(id)
        response = perform(:delete, "folder/#{id}", nil, token_headers)
        response.nil? ? nil : response.status
      end

      # FIXME: this is going to need better exception handling for multiple GET requests
      # get_folder_messages:  Retrieves all messages
      def get_folder_messages(folder_id)
        folder = get_folder(folder_id).attributes
        page_count = (folder[:count] / MHV_MAXIMUM_PER_PAGE.to_f).ceil
        json = { data: [], errors: {}, metadata: {} }

        (1..page_count).each do |page|
          path = "folder/#{folder_id}/message/page/#{page}/pageSize/#{MHV_MAXIMUM_PER_PAGE}"
          page_data = perform(:get, path, nil, token_headers)[:data]
          json[:data].concat(page_data)
        end

        Common::Collection.new(Message, json)
      end
    end
  end
end
