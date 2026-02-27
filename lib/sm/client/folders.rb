# frozen_string_literal: true

module SM
  class Client < Common::Client::Base
    ##
    # Module containing folder-related methods for the SM Client
    #
    module Folders
      ##
      # Get a collection of Folders
      #
      # @return [Common::Collection[Folder]]
      #
      def get_folders(user_uuid, use_cache)
        path = 'folder'
        path = append_requires_oh_messages_query(path)

        cache_key = "#{user_uuid}-folders"
        get_cached_or_fetch_data(use_cache, cache_key, Folder) do
          json = perform(:get, path, nil, token_headers).body
          Vets::Collection.new(json[:data], Folder, metadata: json[:metadata], errors: json[:errors])
        end
      end

      ##
      # Get a single Folder
      #
      # @return [Folder]
      #
      def get_folder(id)
        path = "folder/#{id}"
        path = append_requires_oh_messages_query(path)

        json = perform(:get, path, nil, token_headers).body
        Folder.new(json[:data].merge(json[:metadata]))
      end

      ##
      # Create a Folder
      #
      # @param name [String] name for the folder
      # @return [Folder]
      #
      def post_create_folder(name)
        json = perform(:post, 'folder', { 'name' => name }, token_headers).body
        Folder.new(json[:data].merge(json[:metadata]))
      end

      ##
      # Rename a Folder
      #
      # @param folder_id [Fixnum] id of the Folder
      # @param name [String] new name for the folder
      # @return [Folder]
      #
      def post_rename_folder(folder_id, name)
        json = perform(:post, "folder/#{folder_id}/rename", { 'folderName' => name }, token_headers).body
        Folder.new(json[:data].merge(json[:metadata]))
      end

      ##
      # Delete a Folder
      #
      # @param id [Fixnum] id of the Folder
      # @return [Fixnum] the status code of the response
      #
      def delete_folder(id)
        response = perform(:delete, "folder/#{id}", nil, token_headers)
        response&.status
      end

      ##
      # Get a collection of Messages
      #
      # @return [Common::Collection]
      #
      def get_folder_messages(user_uuid, folder_id, use_cache)
        cache_key = "#{user_uuid}-folder-messages-#{folder_id}"
        get_cached_or_fetch_data(use_cache, cache_key, Message) do
          json = fetch_all_folder_messages(folder_id)
          is_oh = json[:data].any? { |msg| msg[:is_oh_message] == true }
          result = Vets::Collection.new(json[:data], Message, metadata: json[:metadata], errors: json[:errors])
          track_metric('get_folder_messages', is_oh:, status: 'success')
          result
        rescue => e
          track_metric('get_folder_messages', is_oh: false, status: 'failure')
          raise e
        end
      end

      private

      def fetch_all_folder_messages(folder_id)
        page = 1
        json = { data: [], errors: {}, metadata: {} }

        loop do
          path = "folder/#{folder_id}/message/page/#{page}/pageSize/#{MHV_MAXIMUM_PER_PAGE}"
          path = append_requires_oh_messages_query(path)
          page_data = perform(:get, path, nil, token_headers).body
          json[:data].concat(page_data[:data])
          json[:metadata].merge(page_data[:metadata])
          break unless page_data[:data].size == MHV_MAXIMUM_PER_PAGE

          page += 1
        end
        json
      end

      public

      ##
      # Get a collection of Threads
      #
      # @param folder_id [Fixnum] id of the user's folder (0 Inbox, -1 Sent, -2 Drafts, -3 Deleted, > 0 for custom)
      # @param page_start [Fixnum] Pagination start numbering
      # @param page_end [Fixnum] Pagination end numbering (max: 100)
      # @param sort_field [String] field to sort results by (SENDER_NAME or RECIPIENT_NAME or SENT_DATE or DRAFT_DATE)
      # @param sort_order [String] order to sort results by (ASC for Ascending or DESC for Descending)
      #
      # @return [Common::Collection]
      #
      def get_folder_threads(folder_id, params)
        base_path = "folder/threadlistview/#{folder_id}"
        query_params = [
          "pageSize=#{params[:page_size]}",
          "pageNumber=#{params[:page_number]}",
          "sortField=#{params[:sort_field]}",
          "sortOrder=#{params[:sort_order]}"
        ].join('&')
        path = "#{base_path}?#{query_params}"
        path = append_requires_oh_messages_query(path)

        json = perform(:get, path, nil, token_headers).body
        is_oh = json[:data].any? { |msg| msg[:is_oh_message] == true }
        result = Vets::Collection.new(json[:data], MessageThread, metadata: json[:metadata], errors: json[:errors])
        track_metric('get_folder_threads', is_oh:, status: 'success')
        result
      rescue => e
        track_metric('get_folder_threads', is_oh: false, status: 'failure')
        raise e
      end

      ##
      # Run a search of messages in the given folder
      #
      # @param folder_id [Fixnum] id of the folder to search
      # @param page_num [Fixnum] page number of results to return
      # @param page_size [Fixnum] number of messages per page
      # @param args [Hash] arguments for the message search
      # @return [Common::Collection]
      #
      def post_search_folder(folder_id, page_num, page_size, args = {})
        page_num ||= 1
        page_size ||= MHV_MAXIMUM_PER_PAGE

        path = "folder/#{folder_id}/searchMessage/page/#{page_num}/pageSize/#{page_size}"
        path = append_requires_oh_messages_query(path)

        json = perform(:post,
                       path,
                       args.attributes,
                       token_headers).body
        Vets::Collection.new(json[:data], Message, metadata: json[:metadata], errors: json[:errors])
      end
    end
  end
end
