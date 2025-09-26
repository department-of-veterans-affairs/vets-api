# frozen_string_literal: true

module SM
  class Client
    module Folders
      ##
      # Fetch collection of folders (cached per user if enabled)
      # @param user_uuid [String]
      # @param use_cache [Boolean]
      # @return [Vets::Collection<Folder>]
      def get_folders(user_uuid, use_cache)
        path = append_requires_oh_messages_query('folder')
        cache_key = "#{user_uuid}-folders"
        get_cached_or_fetch_data(use_cache, cache_key, Folder) do
          json = perform(:get, path, nil, token_headers).body
          data = Vets::Collection.new(json[:data], Folder,
                                      metadata: json[:metadata], errors: json[:errors])
          Folder.set_cached(cache_key, data.records) unless Flipper.enabled?(:mhv_secure_messaging_no_cache)
          data
        end
      end

      ##
      # Fetch a single folder
      # @param id [Integer]
      # @return [Folder]
      def get_folder(id)
        path = append_requires_oh_messages_query("folder/#{id}")
        json = perform(:get, path, nil, token_headers).body
        Folder.new(json[:data].merge(json[:metadata]))
      end

      ##
      # Create a folder
      # @param name [String]
      # @return [Folder]
      def post_create_folder(name)
        json = perform(:post, 'folder', { 'name' => name }, token_headers).body
        Folder.new(json[:data].merge(json[:metadata]))
      end

      ##
      # Rename an existing folder
      # @param folder_id [Integer]
      # @param name [String]
      # @return [Folder]
      def post_rename_folder(folder_id, name)
        json = perform(:post, "folder/#{folder_id}/rename", { 'folderName' => name }, token_headers).body
        Folder.new(json[:data].merge(json[:metadata]))
      end

      ##
      # Delete a folder
      # @param id [Integer]
      # @return [Integer, nil] HTTP status
      def delete_folder(id)
        perform(:delete, "folder/#{id}", nil, token_headers)&.status
      end

      ##
      # Fetch paged messages for a folder, auto-paging until exhaustion
      # @param user_uuid [String]
      # @param folder_id [Integer]
      # @param use_cache [Boolean]
      # @return [Vets::Collection<Message>]
      def get_folder_messages(user_uuid, folder_id, use_cache)
        cache_key = "#{user_uuid}-folder-messages-#{folder_id}"
        get_cached_or_fetch_data(use_cache, cache_key, Message) do
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
          messages = Vets::Collection.new(json[:data], Message,
                                          metadata: json[:metadata], errors: json[:errors])
          Message.set_cached(cache_key, messages.records) unless Flipper.enabled?(:mhv_secure_messaging_no_cache)
          messages
        end
      end

      ##
      # Fetch a thread list for a folder
      # @param folder_id [Integer]
      # @param params [Hash] expects :page_size, :page_number, :sort_field, :sort_order
      # @return [Vets::Collection<MessageThread>]
      def get_folder_threads(folder_id, params)
        base_path = "folder/threadlistview/#{folder_id}"
        query_params = [
          "pageSize=#{params[:page_size]}",
          "pageNumber=#{params[:page_number]}",
          "sortField=#{params[:sort_field]}",
          "sortOrder=#{params[:sort_order]}"
        ].join('&')
        path = append_requires_oh_messages_query("#{base_path}?#{query_params}")
        json = perform(:get, path, nil, token_headers).body
        Vets::Collection.new(json[:data], MessageThread, metadata: json[:metadata], errors: json[:errors])
      end

      ##
      # Search messages within a folder
      # @param folder_id [Integer]
      # @param page_num [Integer]
      # @param page_size [Integer]
      # @param args [Hash] search criteria
      # @return [Vets::Collection<Message>]
      def post_search_folder(folder_id, page_num, page_size, args = {})
        page_num  ||= 1
        page_size ||= MHV_MAXIMUM_PER_PAGE
        path = append_requires_oh_messages_query(
          "folder/#{folder_id}/searchMessage/page/#{page_num}/pageSize/#{page_size}"
        )
        json = perform(:post, path, args.attributes, token_headers).body
        Vets::Collection.new(json[:data], Message, metadata: json[:metadata], errors: json[:errors])
      end
    end
  end
end
