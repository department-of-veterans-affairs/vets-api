# frozen_string_literal: true

module SM
  class Client < Common::Client::Base
    ##
    # Module containing message-related methods for the SM Client
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
        Vets::Collection.new(json[:data], MessageThreadDetails, metadata: json[:metadata], errors: json[:errors])
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
        Vets::Collection.new(json[:data], MessageThreadDetails, metadata: json[:metadata], errors: json[:errors])
      end

      ##
      # Create a message
      #
      # @param args [Hash] a hash of message arguments
      # @return [Message]
      # @raise [Common::Exceptions::ValidationErrors] if message create context is invalid
      #
      def post_create_message(args = {}, poll_for_status: false, **kwargs)
        args.merge!(kwargs)
        validate_create_context(args)
        json = perform(:post, 'message', args.to_h, token_headers).body
        message = Message.new(json[:data].merge(json[:metadata]))
        return poll_status(message) if poll_for_status

        message
      end

      ##
      # Create a message with an attachment
      #
      # @param args [Hash] a hash of message arguments
      # @return [Message]
      # @raise [Common::Exceptions::ValidationErrors] if message create context is invalid
      #
      def post_create_message_with_attachment(args = {}, poll_for_status: false, **kwargs)
        args.merge!(kwargs)
        validate_create_context(args)
        Rails.logger.info('MESSAGING: post_create_message_with_attachments')
        custom_headers = token_headers.merge('Content-Type' => 'multipart/form-data')
        json = perform(:post, 'message/attach', args.to_h, custom_headers).body
        message = Message.new(json[:data].merge(json[:metadata]))
        return poll_status(message) if poll_for_status

        message
      end

      ##
      # Create a message with attachments
      # Utilizes MHV S3 presigned URLs to upload large attachments
      # bypassing the 10MB limit of the MHV API gateway limitation
      #
      # @param args [Hash] a hash of message arguments
      # @return [Message]
      # @raise [Common::Exceptions::ValidationErrors] if message create context is invalid
      #
      def post_create_message_with_lg_attachments(args = {}, poll_for_status: false, **kwargs)
        args.merge!(kwargs)
        validate_create_context(args)
        Rails.logger.info('MESSAGING: post_create_message_with_lg_attachments')
        message = create_message_with_lg_attachments_request('message/attach', args)
        return poll_status(message) if poll_for_status

        message
      end

      ##
      # Create a message reply with an attachment
      #
      # @param args [Hash] a hash of message arguments
      # @return [Message]
      # @raise [Common::Exceptions::ValidationErrors] if message reply context is invalid
      #
      def post_create_message_reply_with_attachment(id, args = {}, poll_for_status: false, **kwargs)
        args.merge!(kwargs)
        validate_reply_context(args)
        Rails.logger.info('MESSAGING: post_create_message_reply_with_attachment')
        custom_headers = token_headers.merge('Content-Type' => 'multipart/form-data')
        json = perform(:post, "message/#{id}/reply/attach", args.to_h, custom_headers).body
        message = Message.new(json[:data].merge(json[:metadata]))
        return poll_status(message) if poll_for_status

        message
      end

      ##
      # Create a message reply with attachments
      # Utilizes MHV S3 presigned URLs to upload large attachments
      # bypassing the 10MB limit of the MHV API gateway limitation
      #
      # @param args [Hash] a hash of message arguments
      # @return [Message]
      # @raise [Common::Exceptions::ValidationErrors] if message create context is invalid
      #
      def post_create_message_reply_with_lg_attachment(id, args = {}, poll_for_status: false, **kwargs)
        args.merge!(kwargs)
        validate_reply_context(args)
        Rails.logger.info('MESSAGING: post_create_message_reply_with_lg_attachment')
        message = create_message_with_lg_attachments_request("message/#{id}/reply/attach", args)
        return poll_status(message) if poll_for_status

        message
      end

      ##
      # Create a message reply
      #
      # @param args [Hash] a hash of message arguments
      # @return [Message]
      # @raise [Common::Exceptions::ValidationErrors] if message reply context is invalid
      #
      def post_create_message_reply(id, args = {}, poll_for_status: false, **kwargs)
        args.merge!(kwargs)
        validate_reply_context(args)
        json = perform(:post, "message/#{id}/reply", args.to_h, token_headers).body
        message = Message.new(json[:data].merge(json[:metadata]))
        return poll_status(message) if poll_for_status

        message
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

      private

      def validate_create_context(args)
        if args[:id].present? && reply_draft?(args[:id])
          draft = ::MessageDraft.new(args.merge(has_message: true)).as_reply
          draft.errors.add(:base, 'attempted to use reply draft in send message')
          raise Common::Exceptions::ValidationErrors, draft
        end
      end

      def validate_reply_context(args)
        if args[:id].present? && !reply_draft?(args[:id])
          draft = ::MessageDraft.new(args)
          draft.errors.add(:base, 'attempted to use plain draft in send reply')
          raise Common::Exceptions::ValidationErrors, draft
        end
      end
    end
  end
end
