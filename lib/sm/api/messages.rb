# frozen_string_literal: true
require 'common/models/collection'

module SM
  module API
    module Messages
      def get_categories
        path = 'message/category'
        json = perform(:get, path, nil, token_headers).body

        Category.new(json)
      end

      # get_message: Retrieves a specific message by id, marking the message as read.
      def get_message(id)
        path = "message/#{id}/read"
        json = perform(:get, path, nil, token_headers).body

        Message.new(json)
      end

      # get_message_history: Retrieves a thread of messages, not including the message whosse history
      # is being returned.
      def get_message_history(id)
        path = "message/#{id}/history"
        json = perform(:get, path, nil, token_headers).body

        Common::Collection.new(Message, json)
      end

      # get_message_category: Retrieves a specific message by id, marking the message as read.
      def get_message_category
        path = 'message/category'
        json = perform(:get, path, nil, token_headers).body

        Category.new(json)
      end

      # post_create_message: Creates a new message, without attachments
      def post_create_message(args = {})
        r = perform(:post, 'message', args, token_headers)
        json = r.body

        Message.new(json)
      end

      def post_create_message_with_attachment(args = {})
        params  = { uploads: args.delete(:uploads), message: args }

        json = perform(:post, 'message/attach', params, token_headers).body
        Message.new(json)
      end

      def post_create_message_reply_with_attachment(id, args = {})
        params  = { uploads: args.delete(:uploads), message: args }

        json = perform(:post, "message/#{id}/reply/attach", params, token_headers).body
        Message.new(json)
      end

      # post_create_message_reply: Replies to a message with the given id,
      # or updates an existing reply, without attachments
      def post_create_message_reply(id, args = {})
        json = perform(:post, "message/#{id}/reply", args, token_headers).body

        Message.new(json)
      end

      # post_move_message: Moves a message from its current folder to another
      def post_move_message(id, folder_id)
        response = perform(:post, "message/#{id}/move/tofolder/#{folder_id}", nil, token_headers)

        response.nil? ? nil : response.status
      end

      # delete_folder: Deletes a folder.
      def delete_message(id)
        response = perform(:delete, "message/#{id}", nil, token_headers)
        
        response.nil? ? nil : response.status
      end

    end
  end
end
