# frozen_string_literal: true

module RuboCop
  module Cop
    module Sre
      # Play 17 - Prefer structured logging over string interpolation.
      #
      # String-interpolated log messages are harder to search, alert on, and
      # parse. Use structured logging with keyword arguments or a hash.
      #
      # @example
      #   # bad
      #   Rails.logger.error("User #{user_id} failed: #{e.message}")
      #   logger.warn("Request to #{url} returned #{status}")
      #
      #   # good
      #   Rails.logger.error("Request failed", user_id: user_id, error: e.class.name)
      #   logger.warn("Upstream error", url: url, status: status)
      class PreferStructuredLogs < Base
        MSG = '[Play 17] String interpolation in log message. ' \
              'Prefer structured logging: `logger.error("msg", key: value)`.'

        LOG_METHODS = %i[error warn info debug].freeze

        def on_send(node)
          return unless LOG_METHODS.include?(node.method_name)
          return unless logger_receiver?(node.receiver)
          return if node.arguments.empty?

          first_arg = node.arguments.first
          return unless first_arg.dstr_type?

          add_offense(node)
        end

        private

        def logger_receiver?(receiver)
          return false unless receiver

          # logger.error(...) or Rails.logger.error(...)
          receiver.send_type? && receiver.method?(:logger)
        end
      end
    end
  end
end
