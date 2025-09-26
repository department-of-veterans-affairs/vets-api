# frozen_string_literal: true

module SM
  class Client
    module Messages
      ##
      # Fetch message categories
      # @return [Category]
      def get_categories
        json = perform(:get, 'message/category', nil, token_headers).body
        Category.new(json[:data])
      end

      ##
      # Fetch a single message (marks as read upstream)
      # @param id [Integer]
      # @return [Message]
      def get_message(id)
        json = perform(:get, "message/#{id}/read", nil, token_headers).body
        Message.new(json[:data].merge(json[:metadata]))
      end

      ##
      # Legacy message thread (history) endpoint
      # @param id [Integer] message id (root of thread)
      # @return [Vets::Collection<Message>]
      def get_message_history(id)
        json = perform(:get, "message/#{id}/history", nil, token_headers).body
        Vets::Collection.new(json[:data], Message, metadata: json[:metadata], errors: json[:errors])
      end

      ##
      # Fetch condensed thread messages (no full bodies / limited fields)
      # @param id [Integer]
      # @return [Vets::Collection<MessageThreadDetails>]
      def get_messages_for_thread(id)
        path = append_requires_oh_messages_query("message/#{id}/messagesforthread")
        json = perform(:get, path, nil, token_headers).body
        Vets::Collection.new(json[:data], MessageThreadDetails, metadata: json[:metadata], errors: json[:errors])
      end

      ##
      # Fetch full thread messages including attachments
      # @param id [Integer]
      # @return [Vets::Collection<MessageThreadDetails>]
      def get_full_messages_for_thread(id)
        path = append_requires_oh_messages_query("message/#{id}/allmessagesforthread/1")
        json = perform(:get, path, nil, token_headers).body
        Vets::Collection.new(json[:data], MessageThreadDetails, metadata: json[:metadata], errors: json[:errors])
      end

      ##
      # Create (send) a new message
      # Supports keyword args for convenience:
      #   post_create_message(subject: 's', body: 'b', recipient_id: 1, category: 'OTHER')
      #
      # @param args [Hash,nil]
      # @param poll_for_status [Boolean] whether to poll OH status endpoint synchronously
      # @return [Message]
      def post_create_message(args = nil, poll_for_status: false, **kwargs)
        args = (args || {}).merge(kwargs)
        validate_create_context(args)
        message = do_message_post('message', args.to_h)
        return message unless poll_for_status

        poll_status(message, timeout_seconds: 60, interval_seconds: 1, max_errors: 2)
      end

      ##
      # Create a new message with standard (<= gateway limit) attachments
      def post_create_message_with_attachment(args = nil, poll_for_status: false, **kwargs)
        args = (args || {}).merge(kwargs)
        validate_create_context(args)
        message = do_message_post('message/attach', args.to_h, multipart: true)
        return message unless poll_for_status

        poll_status(message, timeout_seconds: 60, interval_seconds: 1, max_errors: 2)
      end

      ##
      # Create a new message with large attachments (S3 presigned workflow)
      def post_create_message_with_lg_attachments(args = nil, poll_for_status: false, **kwargs)
        args = (args || {}).merge(kwargs)
        validate_create_context(args)
        Rails.logger.info('MESSAGING: post_create_message_with_lg_attachments')
        message = create_message_with_lg_attachments_request('message/attach', args)
        return message unless poll_for_status

        poll_status(message, timeout_seconds: 60, interval_seconds: 1, max_errors: 2)
      end

      ##
      # Create a reply (no attachments)
      def post_create_message_reply(id, args = nil, poll_for_status: false, **kwargs)
        args = (args || {}).merge(kwargs)
        validate_reply_context(args)
        message = do_message_post("message/#{id}/reply", args.to_h)
        return message unless poll_for_status

        poll_status(message, timeout_seconds: 60, interval_seconds: 1, max_errors: 2)
      end

      ##
      # Create a reply with standard attachments
      def post_create_message_reply_with_attachment(id, args = nil, poll_for_status: false, **kwargs)
        args = (args || {}).merge(kwargs)
        validate_reply_context(args)
        message = do_message_post("message/#{id}/reply/attach", args.to_h, multipart: true)
        return message unless poll_for_status

        poll_status(message, timeout_seconds: 60, interval_seconds: 1, max_errors: 2)
      end

      ##
      # Create a reply with large attachments (S3 presigned workflow)
      def post_create_message_reply_with_lg_attachment(id, args = nil, poll_for_status: false, **kwargs)
        args = (args || {}).merge(kwargs)
        validate_reply_context(args)
        Rails.logger.info('MESSAGING: post_create_message_reply_with_lg_attachment')
        message = create_message_with_lg_attachments_request("message/#{id}/reply/attach", args)
        return message unless poll_for_status

        poll_status(message, timeout_seconds: 60, interval_seconds: 1, max_errors: 2)
      end

      ##
      # Move a message to a folder
      # @return [Integer,nil] HTTP status
      def post_move_message(id, folder_id)
        perform(:post,
                "message/#{id}/move/tofolder/#{folder_id}",
                nil,
                token_headers.merge('Content-Type' => 'application/json'))&.status
      end

      ##
      # Move a thread to a folder
      def post_move_thread(id, folder_id)
        perform(:post,
                "message/#{id}/movethreadmessages/tofolder/#{folder_id}",
                nil,
                token_headers.merge('Content-Type' => 'application/json'))&.status
      end

      ##
      # Delete (soft-delete) a message
      def delete_message(id)
        perform(:post,
                "message/#{id}",
                nil,
                token_headers.merge('Content-Type' => 'application/json'))&.status
      end

      private

      # Internal helper for posting message/reply (with/without attachments)
      def do_message_post(path, payload, multipart: false)
        headers = token_headers
        headers = headers.merge('Content-Type' => 'multipart/form-data') if multipart
        json = perform(:post, path, payload, headers).body
        Message.new(json[:data].merge(json[:metadata]))
      end
    end
  end
end
