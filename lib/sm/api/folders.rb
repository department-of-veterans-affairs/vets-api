# frozen_string_literal: true
require 'common/models/collection'

module SM
  module API
    module Folders
      MAXIMUM_PER_PAGE = 250

      # get_folders: Retrieves a set of folders. The set may be optionally paginated by
      # specifying a page and a page_size (> 0).
      def get_folders(page = 1, page_size = -1)
        json = perform(:get, 'folder', nil, token_headers)
        collection = Common::Collection.new(Folder, json)

        page_size.positive? ? collection.paginate(page: page, per_page: page_size) : collection
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

      # get_folder_messages:  Retrieves a paginated set of messages (which defaults
      # to page 1 with 10 elements per page)
      def get_folder_messages(id, page, per_page, all = false)
        json = { data: [], errors: {}, metadata: {} }
        pages, per_page, count = page_params(id, page, per_page, all)

        pages.each do |p|
          path = "folder/#{id}/message/page/#{p}/pageSize/#{per_page}"
          json[:data].concat(perform(:get, path, nil, token_headers)[:data])
        end

        json[:metadata] = { folder_id: id, current_page: pages.first, per_page: per_page, count: count }
        Common::Collection.new(Message, json)
      end

      protected

      # Sets page ranges and per_page based on whether all messages or a subset of messages
      # are being retrieved.
      def page_params(id, page, per_page, all)
        folder = get_folder(id).attributes
        page ||= 1
        per_page = [per_page || MAXIMUM_PER_PAGE].min
        pages = all ? 1..(folder[:count].to_f / per_page).ceil : page..page

        [pages, per_page, folder[:count]]
      end
    end
  end
end
