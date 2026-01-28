# frozen_string_literal: true

module SM
  class Client < Common::Client::Base
    ##
    # Module containing message retrieval and management methods for the SM Client
    #
    module Messages
      ##
      # Get message categories
      #
      # @return [Category]
      #
      def get_categories
        path = 'message/category'

        json = perform(:get, path, nil, token_headers).body
        Category.new(json[:data])
      end

      ##
      # Get a message
      #
      # @param id [Fixnum] message id
      # @return [Message]
      #
      def get_message(id)
        path = "message/#{id}/read"
        json = perform(:get, path, nil, token_headers).body
        Message.new(json[:data].merge(json[:metadata]))
      end

      ##
      # Get a message thread old api
      #
      # @param id [Fixnum] message id
      # @return [Common::Collection[Message]]
      #
      def get_message_history(id)
        path = "message/#{id}/history"
        json = perform(:get, path, nil, token_headers).body
        Vets::Collection.new(json[:data], Message, metadata: json[:metadata], errors: json[:errors])
      end

      ##
      # Get a message thread
      #
      # @param id [Fixnum] message id
      # @return [Common::Collection[MessageThread]]
      #
      def get_messages_for_thread(id)
        path = "message/#{id}/messagesforthread"
        path = append_requires_oh_messages_query(path)

        json = perform(:get, path, nil, token_headers).body
        is_oh = json[:data].any? { |msg| msg[:is_oh_message] == true }
        result = Vets::Collection.new(json[:data], MessageThreadDetails, metadata: json[:metadata],
                                                                         errors: json[:errors])
        track_metric('get_messages_for_thread', is_oh:, status: 'success')
        result
      rescue => e
        track_metric('get_messages_for_thread', is_oh: false, status: 'failure')
        raise e
      end

      ##
      # Get a message thread with full body and attachments
      #
      # @param id [Fixnum] message id
      # @return [Common::Collection[MessageThreadDetails]]
      #
      def get_full_messages_for_thread(id)
        path = "message/#{id}/allmessagesforthread/1"
        path = append_requires_oh_messages_query(path)
        json = perform(:get, path, nil, token_headers).body
        is_oh = json[:data].any? { |msg| msg[:is_oh_message] == true }
        result = Vets::Collection.new(json[:data], MessageThreadDetails, metadata: json[:metadata],
                                                                         errors: json[:errors])
        track_metric('get_full_messages_for_thread', is_oh:, status: 'success')
        result
      rescue => e
        track_metric('get_full_messages_for_thread', is_oh: false, status: 'failure')
        raise e
      end

      ##
      # Move a message to a given folder
      #
      # @param id [Fixnum] the {Message} id
      # @param folder_id [Fixnum] the {Folder} id
      # @return [Fixnum] the response status code
      #
      def post_move_message(id, folder_id)
        custom_headers = token_headers.merge('Content-Type' => 'application/json')
        response = perform(:post, "message/#{id}/move/tofolder/#{folder_id}", nil, custom_headers)

        response&.status
      end

      ##
      # Move a thread to a given folder
      #
      # @param id [Fixnum] the thread id
      # @param folder_id [Fixnum] the {Folder} id
      # @return [Fixnum] the response status code
      #
      def post_move_thread(id, folder_id)
        custom_headers = token_headers.merge('Content-Type' => 'application/json')
        response = perform(:post, "message/#{id}/movethreadmessages/tofolder/#{folder_id}", nil, custom_headers)
        response&.status
      end

      ##
      # Delete a message
      #
      # @param id [Fixnum] id of message to be deleted
      # @return [Fixnum] the response status code
      #
      def delete_message(id)
        custom_headers = token_headers.merge('Content-Type' => 'application/json')
        response = perform(:post, "message/#{id}", nil, custom_headers)

        response&.status
      end
    end
  end
end
