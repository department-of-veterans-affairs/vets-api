# frozen_string_literal: true

require 'sm/client/message_status'
require 'sm/client/attachments'

module SM
  class Client < Common::Client::Base
    include Vets::SharedLogging
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
        json = perform_with_logging(:post, 'message', args)
        build_message_response(json, poll_for_status, 'post_create_message')
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
        json = perform_with_logging(:post, 'message/attach', args, headers: multipart_headers)
        build_message_response(json, poll_for_status, 'post_create_message_with_attachment')
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
        build_lg_message_response(message, poll_for_status, 'post_create_message_with_lg_attachments')
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
        json = perform_with_logging(:post, "message/#{id}/reply/attach", args, headers: multipart_headers)
        build_message_response(json, poll_for_status, 'post_create_message_reply_with_attachment')
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
        build_lg_message_response(message, poll_for_status, 'post_create_message_reply_with_lg_attachment')
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
        json = perform_with_logging(:post, "message/#{id}/reply", args)
        build_message_response(json, poll_for_status, 'post_create_message_reply')
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

      def perform_with_logging(method, path, args, headers: token_headers)
        perform(method, path, args.to_h, headers).body
      rescue => e
        if oh_pilot_user?
          log_exception_to_rails('MHV SM OH Pilot User: Message Send Failed', {
                                   error: e.message,
                                   recipient_id: args[:recipient_id].to_s[-6..],
                                   path:,
                                   mhv_correlation_id: "****#{current_user&.mhv_correlation_id.to_s[-6..]}",
                                   client_type: client_type_name
                                 })
        end
        raise e
      end

      def multipart_headers
        token_headers.merge('Content-Type' => 'multipart/form-data')
      end

      def build_message_response(json, poll_for_status, method_name)
        message = Message.new(json[:data].merge(json[:metadata]))
        build_lg_message_response(message, poll_for_status, method_name)
      end

      def build_lg_message_response(message, poll_for_status, method_name)
        log_oh_pilot_message(message, method_name)
        return poll_status(message) if poll_for_status

        message
      end

      def log_oh_pilot_message(message, method_name)
        return unless oh_pilot_user?

        log_message_to_rails("MHV SM OH Pilot User: #{method_name}",
                             {
                               message_id: message&.id,
                               recipient_id: message&.recipient_id.to_s[-6..],
                               is_oh_message: message&.is_oh_message,
                               mhv_correlation_id: "****#{current_user&.mhv_correlation_id.to_s[-6..]}",
                               client_type: client_type_name
                             }, 'info')
      end
    end
  end
end
