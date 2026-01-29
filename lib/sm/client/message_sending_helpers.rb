# frozen_string_literal: true

module SM
  class Client < Common::Client::Base
    ##
    # Helper methods for message sending operations
    #
    module MessageSendingHelpers
      private

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

        log_message_to_rails("MHV SM OH Pilot User: #{method_name}", 'info', {
                               message_id: message&.id,
                               recipient_id: "***#{message&.recipient_id&.to_s&.last(6)}",
                               is_oh_message: message&.is_oh_message,
                               mhv_correlation_id: "****#{current_user&.mhv_correlation_id.to_s.last(6)}",
                               client_type: client_type_name
                             })
      end
    end
  end
end
