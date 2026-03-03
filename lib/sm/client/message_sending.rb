# frozen_string_literal: true

require 'sm/client/message_status'
require 'sm/client/attachments'
require 'sm/client/message_sending_helpers'

module SM
  class Client < Common::Client::Base
    include Vets::SharedLogging
    ##
    # Module containing message sending and reply methods for the SM Client
    #
    module MessageSending
      include MessageSendingHelpers
      ##
      # Create a message
      #
      # @param args [Hash] a hash of message arguments
      # @return [Message]
      # @raise [Common::Exceptions::ValidationErrors] if message create context is invalid
      #
      def post_create_message(args = {}, is_oh: false, **kwargs)
        args.merge!(kwargs)
        track_with_status('post_create_message', is_oh:) do |tags|
          validate_create_context(args)
          path = renewal_message?(args) ? 'message/renewal' : 'message'
          json = perform_with_logging(:post, path, args)
          tags[:station_number] = resolve_station_number(json.dig(:data, :recipient_id))
          build_message_response(json, is_oh, 'post_create_message')
        end
      end

      ##
      # Create a message with an attachment
      #
      # @param args [Hash] a hash of message arguments
      # @return [Message]
      # @raise [Common::Exceptions::ValidationErrors] if message create context is invalid
      #
      def post_create_message_with_attachment(args = {}, is_oh: false, **kwargs)
        args.merge!(kwargs)
        track_with_status('post_create_message_with_attachment', is_oh:) do |tags|
          validate_create_context(args)
          Rails.logger.info('MESSAGING: post_create_message_with_attachments')
          path = renewal_message?(args) ? 'message/renewal/attach' : 'message/attach'
          json = perform_with_logging(:post, path, args, headers: multipart_headers)
          tags[:station_number] = resolve_station_number(json.dig(:data, :recipient_id))
          build_message_response(json, is_oh, 'post_create_message_with_attachment')
        end
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
      def post_create_message_with_lg_attachments(args = {}, is_oh: false, **kwargs)
        args.merge!(kwargs)
        track_with_status('post_create_message_with_lg_attachments', is_oh:) do |tags|
          validate_create_context(args)
          Rails.logger.info('MESSAGING: post_create_message_with_lg_attachments')
          path = renewal_message?(args) ? 'message/renewal/attach' : 'message/attach'
          message = create_message_with_lg_attachments_request(path, args)
          tags[:station_number] = resolve_station_number(message&.recipient_id)
          build_lg_message_response(message, is_oh, 'post_create_message_with_lg_attachments')
        end
      end

      ##
      # Create a message reply with an attachment
      #
      # @param args [Hash] a hash of message arguments
      # @return [Message]
      # @raise [Common::Exceptions::ValidationErrors] if message reply context is invalid
      # @raise [Common::Exceptions::ParameterMissing] if id is blank
      #
      def post_create_message_reply_with_attachment(id, args = {}, is_oh: false, **kwargs)
        raise Common::Exceptions::ParameterMissing, 'id' if id.blank?

        args.merge!(kwargs)
        track_with_status('post_create_message_reply_with_attachment', is_oh:) do |tags|
          validate_reply_context(args)
          Rails.logger.info('MESSAGING: post_create_message_reply_with_attachment')
          json = perform_with_logging(:post, "message/#{id}/reply/attach", args, headers: multipart_headers)
          tags[:station_number] = resolve_station_number(json.dig(:data, :recipient_id))
          build_message_response(json, is_oh, 'post_create_message_reply_with_attachment')
        end
      end

      ##
      # Create a message reply with attachments
      # Utilizes MHV S3 presigned URLs to upload large attachments
      # bypassing the 10MB limit of the MHV API gateway limitation
      #
      # @param args [Hash] a hash of message arguments
      # @return [Message]
      # @raise [Common::Exceptions::ValidationErrors] if message create context is invalid
      # @raise [Common::Exceptions::ParameterMissing] if id is blank
      #
      def post_create_message_reply_with_lg_attachment(id, args = {}, is_oh: false, **kwargs)
        raise Common::Exceptions::ParameterMissing, 'id' if id.blank?

        args.merge!(kwargs)
        track_with_status('post_create_message_reply_with_lg_attachment', is_oh:) do |tags|
          validate_reply_context(args)
          Rails.logger.info('MESSAGING: post_create_message_reply_with_lg_attachment')
          message = create_message_with_lg_attachments_request("message/#{id}/reply/attach", args)
          tags[:station_number] = resolve_station_number(message&.recipient_id)
          build_lg_message_response(message, is_oh, 'post_create_message_reply_with_lg_attachment')
        end
      end

      ##
      # Create a message reply
      #
      # @param args [Hash] a hash of message arguments
      # @return [Message]
      # @raise [Common::Exceptions::ValidationErrors] if message reply context is invalid
      # @raise [Common::Exceptions::ParameterMissing] if id is blank
      #
      def post_create_message_reply(id, args = {}, is_oh: false, **kwargs)
        raise Common::Exceptions::ParameterMissing, 'id' if id.blank?

        args.merge!(kwargs)
        track_with_status('post_create_message_reply', is_oh:) do |tags|
          validate_reply_context(args)
          json = perform_with_logging(:post, "message/#{id}/reply", args)
          tags[:station_number] = resolve_station_number(json.dig(:data, :recipient_id))
          build_message_response(json, is_oh, 'post_create_message_reply')
        end
      end

      private

      # Checks whether the message args contain a prescription_id, indicating
      # this should be routed to the upstream MHV renewal endpoint.
      # Handles both flat args (post_create_message) and nested args
      # (attachment methods where prescription_id is under the :message key).
      def renewal_message?(args)
        prescription_id = args[:prescription_id] || args.dig(:message, :prescription_id)
        prescription_id.present?
      end

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
        log_message_to_rails('MHV SM: Message Send Failed', 'error', {
                               error: e.message,
                               recipient_id: "***#{args[:recipient_id]&.to_s&.last(6)}",
                               path:,
                               mhv_correlation_id: "****#{current_user&.mhv_correlation_id.to_s.last(6)}",
                               client_type: client_type_name
                             })
        raise e
      end
    end
  end
end
