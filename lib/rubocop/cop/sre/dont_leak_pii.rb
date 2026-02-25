# frozen_string_literal: true

module RuboCop
  module Cop
    module Sre
      # Play 01 - Don't leak PII in error messages or logs.
      #
      # Interpolating `.body` or `.params` into raise messages or logger calls
      # risks exposing veteran PII/PHI in Sentry, logs, or error responses.
      #
      # @example
      #   # bad
      #   raise "Failed: #{response.body}"
      #   Rails.logger.error("Bad request: #{params}")
      #   logger.warn("Response: #{resp.body}")
      #
      #   # good
      #   raise Common::Exceptions::BackendServiceException
      #   Rails.logger.error("Request failed", status: response.status)
      class DontLeakPii < Base
        MSG_RAISE = '[Play 01] Interpolating `.body`/`.params` into raise risks leaking PII. ' \
                    'Raise a typed exception and log sanitized fields separately.'
        MSG_LOG = '[Play 01] Interpolating `.body`/`.params` into log message risks leaking PII. ' \
                  'Use structured logging with sanitized fields.'

        PII_METHODS = %i[body params].freeze
        LOG_METHODS = %i[error warn info debug].freeze

        def on_send(node)
          check_raise(node)
          check_logger(node)
        end

        private

        def check_raise(node)
          return unless node.method?(:raise)
          return unless node.arguments.any? { |arg| dstr_leaks_pii?(arg) }

          add_offense(node, message: MSG_RAISE)
        end

        def check_logger(node)
          return unless LOG_METHODS.include?(node.method_name)
          return unless logger_receiver?(node.receiver)
          return unless node.arguments.any? { |arg| dstr_leaks_pii?(arg) }

          add_offense(node, message: MSG_LOG)
        end

        def logger_receiver?(receiver)
          return false unless receiver&.send_type?

          # Match `logger.error(...)` or `Rails.logger.error(...)`
          receiver.method?(:logger)
        end

        def dstr_leaks_pii?(node)
          return false unless node.dstr_type?

          node.each_descendant(:send).any? do |send_node|
            PII_METHODS.include?(send_node.method_name)
          end
        end
      end
    end
  end
end
