# frozen_string_literal: true

module SM
  class Client
    module StatusPolling
      ##
      # Fetch the current status for a sent (or sending) message.
      # Upstream response example (fields may vary slightly):
      # {
      #   "messageId": 5986481,
      #   "status": "SENT",
      #   "isOhMessage": true,
      #   "ohSecureMessageId": "54280239861.0.-4.prsnl"
      # }
      #
      # This normalizes keys to snake_case symbols and ensures status is upper‑cased.
      #
      # @param message_id [Integer]
      # @return [Hash] { message_id:, status:, is_oh_message:, oh_secure_message_id: }
      def get_message_status(message_id)
        json = perform(:get, "messages/#{message_id}/status", nil, token_headers).body
        data = json.is_a?(Hash) && json[:data].present? ? json[:data] : json
        {
          message_id: data[:message_id] || data[:id] || message_id,
          status: data[:status]&.to_s&.upcase,
          is_oh_message: data.key?(:is_oh_message) ? data[:is_oh_message] : data[:oh_message],
          oh_secure_message_id: data[:oh_secure_message_id]
        }
      end

      ##
      # Poll message status until a terminal state, timeout, or excessive transient failures.
      #
      # Terminal statuses (stop conditions):
      #   SENT, FAILED, INVALID, UNKNOWN, NOT_SUPPORTED
      #
      # Failure handling:
      #   - Raises Common::Exceptions::GatewayTimeout on overall timeout or repeated transient errors
      #
      # @param message_id [Integer]
      # @param timeout_seconds [Integer]
      # @param interval_seconds [Integer]
      # @param max_errors [Integer] allowable consecutive transient failures before giving up
      # @return [Hash] normalized status hash
      # @raise [Common::Exceptions::GatewayTimeout]
      def poll_message_status(message_id, timeout_seconds: 60, interval_seconds: 1, max_errors: 2)
        terminal = %w[SENT FAILED INVALID UNKNOWN NOT_SUPPORTED]
        deadline = Time.zone.now + timeout_seconds
        consecutive_errors = 0

        loop do
          raise Common::Exceptions::GatewayTimeout if Time.zone.now >= deadline

          begin
            result = get_message_status(message_id)
            status = result[:status]
            return result if status && terminal.include?(status)

            consecutive_errors = 0
          rescue Common::Exceptions::GatewayTimeout
            raise
          rescue
            consecutive_errors += 1
            raise Common::Exceptions::GatewayTimeout if consecutive_errors > max_errors
          end

          sleep interval_seconds
        end
      end

      ##
      # Convenience wrapper used by create / reply flows when synchronous OH polling is desired.
      # Raises UnprocessableEntity for FAILED / INVALID terminal outcomes; returns the given
      # message object otherwise (including SENT, UNKNOWN, NOT_SUPPORTED).
      #
      # @param message [Message]
      # @param timeout_seconds [Integer]
      # @param interval_seconds [Integer]
      # @param max_errors [Integer]
      # @return [Message]
      # @raise [Common::Exceptions::UnprocessableEntity]
      def poll_status(message, timeout_seconds: 60, interval_seconds: 1, max_errors: 2)
        result = poll_message_status(
          message.id,
          timeout_seconds:,
          interval_seconds:,
          max_errors:
        )
        raise Common::Exceptions::UnprocessableEntity if %w[FAILED INVALID].include?(result[:status])

        message
      end
    end
  end
end
