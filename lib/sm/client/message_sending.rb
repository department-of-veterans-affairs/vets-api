# frozen_string_literal: true

require 'sm/client/message_status'
require 'sm/client/attachments'

module SM
  class Client < Common::Client::Base
    ##
    # Module containing message sending and reply methods for the SM Client
    #
    module MessageSending
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
