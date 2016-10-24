# frozen_string_literal: true
require 'common/models/collection'

module SM
  module API
    module Messages
      def get_categories
        path = 'message/category'

        json = perform(:get, path, nil, token_headers)
        Category.new(json)
      end

      def get_message(id)
        path = "message/#{id}/read"
        json = perform(:get, path, nil, token_headers)

        Message.new(json)
      end

      def get_message_history(id)
        path = "message/#{id}/history"
        json = perform(:get, path, nil, token_headers)

        Common::Collection.new(Message, json)
      end

      def post_create_message(args = {})
        json = perform(:post, 'message', args, token_headers)
        Message.new(json)
      end

      def post_create_message_with_attachment(args = {})
        custom_header = token_headers.except('Content-Type')
        json = perform(:post, 'message/attach', args, custom_header)
        Message.new(json)
      end

      def post_create_message_reply_with_attachment(id, args = {})
        custom_header = token_headers.except('Content-Type')
        json = perform(:post, "message/#{id}/reply/attach", args, custom_header)
        Message.new(json)
      end

      def post_create_message_reply(id, args = {})
        json = perform(:post, "message/#{id}/reply", args, token_headers)

        Message.new(json)
      end

      def post_move_message(id, folder_id)
        response = perform(:post, "message/#{id}/move/tofolder/#{folder_id}", nil, token_headers)

        response.nil? ? nil : response.status
      end

      def delete_message(id)
        response = perform(:post, "message/#{id}", nil, token_headers)

        response.nil? ? nil : response.status
      end

      def get_attachment(message_id, attachment_id)
        path = "message/#{message_id}/attachment/#{attachment_id}"
        perform(:get, path, nil, token_headers)
      end
    end
  end
end
