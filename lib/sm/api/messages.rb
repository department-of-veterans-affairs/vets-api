# frozen_string_literal: true
require 'common/models/collection'

module SM
  module API
    module Messages
      CONTENT_DISPOSITION = 'attachment; filename='

      def get_categories
        path = 'message/category'

        json = perform(:get, path, nil, token_headers).body
        Category.new(json)
      end

      def get_message(id)
        path = "message/#{id}/read"
        json = perform(:get, path, nil, token_headers).body

        Message.new(json)
      end

      def get_message_history(id)
        path = "message/#{id}/history"
        json = perform(:get, path, nil, token_headers).body

        Common::Collection.new(Message, json)
      end

      def post_create_message(args = {})
        validate_create_context(args)

        json = perform(:post, 'message', args, token_headers).body
        Message.new(json)
      end

      def post_create_message_with_attachment(args = {})
        validate_create_context(args)

        json = perform(:post, 'message/attach', args, token_headers).body
        Message.new(json)
      end

      def post_create_message_reply_with_attachment(id, args = {})
        validate_reply_context(args)

        json = perform(:post, "message/#{id}/reply/attach", args, token_headers).body
        Message.new(json)
      end

      def post_create_message_reply(id, args = {})
        validate_reply_context(args)

        json = perform(:post, "message/#{id}/reply", args, token_headers).body
        Message.new(json)
      end

      def post_move_message(id, folder_id)
        custom_headers = token_headers.merge('Content-Type' => 'application/json')
        response = perform(:post, "message/#{id}/move/tofolder/#{folder_id}", nil, custom_headers)

        response.nil? ? nil : response.status
      end

      def delete_message(id)
        custom_headers = token_headers.merge('Content-Type' => 'application/json')
        response = perform(:post, "message/#{id}", nil, custom_headers)

        response.nil? ? nil : response.status
      end

      def get_attachment(message_id, attachment_id)
        path = "message/#{message_id}/attachment/#{attachment_id}"

        response = perform(:get, path, nil, token_headers)
        filename = response.response_headers['content-disposition'].gsub(CONTENT_DISPOSITION, '')
        { body: response.body, filename: filename }
      end

      def validate_create_context(args)
        if args[:id].present? && reply_draft?(args[:id])
          draft = MessageDraft.new(args.merge(has_message: true)).as_reply
          draft.errors.add(:base, 'attempted to use reply draft in send message')

          raise Common::Exceptions::ValidationErrors, draft
        end
      end

      def validate_reply_context(args)
        if args[:id].present? && !reply_draft?(args[:id])
          draft = MessageDraft.new(args)
          draft.errors.add(:base, 'attempted to use plain draft in send reply')

          raise Common::Exceptions::ValidationErrors, draft
        end
      end
    end
  end
end
