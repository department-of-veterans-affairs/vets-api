# frozen_string_literal: true

module RuboCop
  module Cop
    module Sre
      # Play 01 - Don't leak PII in error messages or logs.
      #
      # Interpolating `.body` or `.params` into raise messages or logger calls
      # risks exposing veteran PII/PHI in Sentry, logs, or error responses.
      #
      # Additionally, passing raw upstream response data (`.original_body`,
      # `.original_error`) as hash values in error responses rendered to clients
      # leaks PII/PHI through a different vector than string interpolation.
      #
      # @example
      #   # bad - string interpolation (original detection)
      #   raise "Failed: #{response.body}"
      #   Rails.logger.error("Bad request: #{params}")
      #   logger.warn("Response: #{resp.body}")
      #
      #   # bad - hash value in rendered error response (new detection)
      #   { meta: { backend_response: error.try(:original_body) } }
      #   { meta: { original_error: error.try(:message), backend_response: error.original_body } }
      #   render json: { errors: [{ meta: { backend_response: e.original_body } }] }
      #
      #   # good
      #   raise Common::Exceptions::BackendServiceException
      #   Rails.logger.error("Request failed", status: response.status)
      #   { meta: { error_class: error.class.name, status: error.original_status } }
      class DontLeakPii < Base
        MSG_RAISE = '[Play 01] Interpolating `.body`/`.params` into raise risks leaking PII. ' \
                    'Raise a typed exception and log sanitized fields separately.'
        MSG_LOG = '[Play 01] Interpolating `.body`/`.params` into log message risks leaking PII. ' \
                  'Use structured logging with sanitized fields.'
        MSG_HASH_VALUE = '[Play 01] Raw upstream response data (`.%<method>s`) in hash value ' \
                         'may leak PII/PHI to clients or logs. Use sanitized fields (status code, ' \
                         'error class, safe identifiers) instead.'

        # Methods whose return values contain raw upstream response data that
        # must never be interpolated into raise/log strings.
        INTERPOLATION_PII_METHODS = %i[body params].freeze

        # Methods whose return values contain raw upstream response data that
        # must never appear as hash values in error responses rendered to clients.
        # These are a superset: `original_body` and `original_error` carry the same
        # risk as `body` but appear in hash-literal contexts rather than dstr.
        HASH_VALUE_PII_METHODS = %i[body original_body original_error params].freeze

        # Common hash keys that signal the value is being used in an error
        # response or log metadata context where PII leakage matters.
        SUSPICIOUS_HASH_KEYS = %i[
          backend_response
          original_body
          original_error
          response_body
          vamf_body
          error_body
          raw_body
          raw_response
        ].freeze

        LOG_METHODS = %i[error warn info debug].freeze

        def on_send(node)
          check_raise(node)
          check_logger(node)
          check_render(node)
        end

        def on_hash(node)
          check_hash_values(node)
        end

        private

        # --- Original checks: string interpolation in raise/logger ---

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
            INTERPOLATION_PII_METHODS.include?(send_node.method_name)
          end
        end

        # --- New check: render json: with hash containing raw response data ---

        def check_render(node)
          return unless node.method?(:render)

          # Look for `render json: { ... }` or `render(json: { ... })`
          node.arguments.each do |arg|
            next unless arg.hash_type?

            arg.pairs.each do |pair|
              next unless pair.key.sym_type? && pair.key.value == :json

              # The value of `json:` is the response body — scan it for PII methods
              scan_hash_tree_for_pii(pair.value, rendered: true)
            end
          end
        end

        # --- New check: hash literals with suspicious keys pointing to raw data ---

        def check_hash_values(node)
          # Only check hash literals that are part of a method body, not kwargs
          # to unrelated methods. We look for hash pairs where:
          # 1. The key is a known suspicious name (backend_response, vamf_body, etc.)
          # 2. The value calls a PII method (.original_body, .body, etc.)
          node.pairs.each do |pair|
            next unless pair.key.sym_type?

            key_name = pair.key.value
            next unless SUSPICIOUS_HASH_KEYS.include?(key_name)

            pii_method = find_pii_method_in_value(pair.value)
            next unless pii_method

            message = format(MSG_HASH_VALUE, method: pii_method)
            add_offense(pair, message: message)
          end
        end

        # Recursively scan a hash tree (nested hashes) for PII method calls.
        # Used when we know the context is a rendered response (render json:).
        def scan_hash_tree_for_pii(node, rendered: false)
          return unless node

          case node.type
          when :hash
            node.pairs.each do |pair|
              pii_method = find_pii_method_in_value(pair.value)
              if pii_method
                message = format(MSG_HASH_VALUE, method: pii_method)
                add_offense(pair, message: message)
              end

              # Recurse into nested hash values
              scan_hash_tree_for_pii(pair.value, rendered: rendered) if pair.value.hash_type?
            end
          when :array
            node.children.each { |child| scan_hash_tree_for_pii(child, rendered: rendered) }
          end
        end

        # Check if a hash value node contains a call to a PII-leaking method.
        # Handles:
        #   - Direct calls:        `error.original_body`
        #   - .try calls:          `error.try(:original_body)`
        #   - .try! calls:         `error.try!(:original_body)`
        #   - Safe navigation:     `error&.original_body`
        #   - Dig calls:           `error.dig(:body)`
        def find_pii_method_in_value(node)
          return nil unless node

          # Walk all send nodes in the value expression
          nodes_to_check = [node]
          nodes_to_check += node.each_descendant(:send, :csend).to_a

          nodes_to_check.each do |send_node|
            next unless send_node.send_type? || send_node.csend_type?

            method_name = send_node.method_name

            # Direct method call: `error.original_body`, `error&.body`
            if HASH_VALUE_PII_METHODS.include?(method_name)
              return method_name
            end

            # .try(:original_body) or .try!(:original_body)
            if %i[try try!].include?(method_name)
              first_arg = send_node.arguments.first
              if first_arg&.sym_type? && HASH_VALUE_PII_METHODS.include?(first_arg.value)
                return first_arg.value
              end
            end

            # .dig(:body) or .dig('body')
            if method_name == :dig
              send_node.arguments.each do |arg|
                if arg.sym_type? && HASH_VALUE_PII_METHODS.include?(arg.value)
                  return arg.value
                end
              end
            end
          end

          nil
        end
      end
    end
  end
end
