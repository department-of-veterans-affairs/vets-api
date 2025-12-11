# frozen_string_literal: true

module SM
  class Client < Common::Client::Base
    ##
    # Module containing message status-related methods for the SM Client
    #
    module MessageStatus
      ##
      # Get message status
      #
      # @param message_id [Fixnum] the message id
      # @return [Hash] the message status
      #
      def get_message_status(message_id)
        path = "message/#{message_id}/status"
        json = perform(:get, path, nil, token_headers).body
        data = json.is_a?(Hash) && json[:data].present? ? json[:data] : json
        {
          message_id: data[:message_id] || data[:id] || message_id,
          status: data[:status]&.to_s&.upcase,
          is_oh_message: data.key?(:is_oh_message) ? data[:is_oh_message] : data[:oh_message],
          oh_secure_message_id: data[:oh_secure_message_id]
        }
      end

      ##
      # Poll OH message status until terminal state or timeout
      #
      # @param message_id [Fixnum] the message id
      # @param timeout_seconds [Fixnum] the timeout in seconds
      # @param interval_seconds [Fixnum] the interval between polls in seconds
      # @param max_errors [Fixnum] the maximum number of consecutive errors before raising
      # @return [Hash] the message status
      #
      def poll_message_status(message_id, timeout_seconds: 60, interval_seconds: 1, max_errors: 2)
        terminal_statuses = %w[SENT FAILED INVALID UNKNOWN NOT_SUPPORTED]
        deadline = Time.zone.now + timeout_seconds
        consecutive_errors = 0

        loop do
          raise Common::Exceptions::GatewayTimeout if Time.zone.now >= deadline

          begin
            result = get_message_status(message_id)
            status = result[:status]
            return result if status && terminal_statuses.include?(status)
          rescue Common::Exceptions::GatewayTimeout
            # Immediately re-raise upstream timeouts
            raise
          rescue => e
            consecutive_errors += 1
            raise e if consecutive_errors > max_errors
          end

          sleep interval_seconds
        end
      end

      private

      ##
      # Polling integration for OH messages on send/reply
      #
      # @param message [Message] the message to poll status for
      # @return [Message] the message with updated status
      #
      def poll_status(message)
        if %w[staging production].include?(Settings.vsp_environment)
          Rails.logger.info("MHV SM: message id #{message.id} is in the OH polling path")
        end
        result = poll_message_status(message.id, timeout_seconds: 60, interval_seconds: 1, max_errors: 2)
        status = result && result[:status]
        if %w[FAILED INVALID].include?(status)
          raise Common::Exceptions::BackendServiceException.new(
            'SM98',
            {
              detail: "OH message send failure with recipient_id #{message.recipient_id} and status #{status}",
              source: self.class.to_s
            }
          )
        end

        message
      end
    end
  end
end
