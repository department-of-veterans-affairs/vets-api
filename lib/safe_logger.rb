# frozen_string_literal: true

# SafeLogger
#
# A standalone logging utility that filters sensitive data before passing to Rails.logger.
# This class does NOT modify Rails.logger behavior - it simply wraps it with filtering.
#
# Usage:
#   # Basic usage (applies default PII filtering)
#   SafeLogger.info("User data", { ssn: "123-45-6789", email: "user@example.com" })
#   # => User data -- {:ssn=>"[FILTERED]", :email=>"[FILTERED]"}
#
#   # With allowlist (specified keys bypass filtering)
#   SafeLogger.info("User data", { ssn: "123-45-6789", email: "user@example.com" }, allowlist: [:email])
#   # => User data -- {:ssn=>"[FILTERED]", :email=>"user@example.com"}
#
# The allowlist parameter accepts an array of symbols or strings representing
# keys that should bypass filtering for that specific log call.
#
# Benefits over extending Rails.logger:
# - Cannot break existing logging behavior
# - Explicit opt-in - developers choose when to use filtering
# - Simpler implementation with no method shadowing
# - Easier to test in isolation
class SafeLogger
  # Regex patterns for filtering object inspect strings
  OBJECT_INSPECT_PATTERN = /#<[A-Z][A-Za-z0-9:]*\s+.*>/
  INSTANCE_VAR_PATTERN = /@(\w+)=("[^"]*"|'[^']*'|\S+)/
  ATTR_COLON_PATTERN = /(\w+):\s*("[^"]*"|'[^']*'|\S+)/

  class << self
    # Log level methods that mirror Rails.logger interface
    %i[debug info warn error fatal].each do |level|
      define_method(level) do |message = nil, payload = nil, allowlist: [], &block|
        filtered_message, filtered_payload = filter_data(message, payload, allowlist)
        Rails.logger.public_send(level, filtered_message, filtered_payload, &block)
      end
    end

    private

    def filter_data(message, payload, allowlist)
      allowlist_strings = Array(allowlist).map(&:to_s)

      begin
        filtered_payload = filter_payload(payload, allowlist_strings)
        filtered_message = filter_message_string(message, allowlist_strings)
        [filtered_message, filtered_payload]
      rescue => e
        # If filtering fails, log the original data rather than breaking the log call
        Rails.logger.warn("SafeLogger filtering error: #{e.message}")
        [message, payload]
      end
    end

    def filter_payload(payload, allowlist)
      return payload unless payload.is_a?(Hash)

      if allowlist.any?
        filter_with_allowlist(payload, allowlist)
      else
        ParameterFilterHelper.filter_params(payload)
      end
    end

    def filter_message_string(message, allowlist)
      return message unless message.is_a?(String) && message.match?(OBJECT_INSPECT_PATTERN)

      filter_object_inspect(message, allowlist)
    end

    def filter_object_inspect(message, allowlist)
      combined_allowlist = build_combined_allowlist(allowlist)
      result = message.dup
      result = filter_instance_vars(result, combined_allowlist)
      filter_colon_attrs(result, combined_allowlist)
    end

    def build_combined_allowlist(allowlist)
      # ALLOWLIST is defined in config/initializers/parameter_filtering.rb
      # It contains keys that should never be filtered (e.g., :id, :status, :controller)
      global_allowlist = defined?(::ALLOWLIST) ? ::ALLOWLIST : []
      (global_allowlist + allowlist).map(&:to_s)
    end

    def filter_instance_vars(result, combined_allowlist)
      result.gsub(INSTANCE_VAR_PATTERN) do |match|
        attr_name = ::Regexp.last_match(1)
        combined_allowlist.include?(attr_name) ? match : "@#{attr_name}=[FILTERED]"
      end
    end

    def filter_colon_attrs(result, combined_allowlist)
      result.gsub(ATTR_COLON_PATTERN) do |match|
        attr_name = ::Regexp.last_match(1)
        combined_allowlist.include?(attr_name) ? match : "#{attr_name}: [FILTERED]"
      end
    end

    def filter_with_allowlist(data, allowlist)
      filter_params = Rails.application.config.filter_parameters
      global_filter = filter_params.is_a?(Array) && filter_params.any? ? filter_params.first : nil

      return ParameterFilterHelper.filter_params(data) unless global_filter.respond_to?(:call)

      # deep_dup prevents mutation of the caller's original data
      filtered_data = data.deep_dup
      apply_allowlist_filter(filtered_data, allowlist, global_filter)
    end

    def apply_allowlist_filter(data, allowlist, global_filter)
      case data
      when Hash
        filter_hash(data, allowlist, global_filter)
      when Array
        data.map { |element| apply_allowlist_filter(element, allowlist, global_filter) }
      else
        data
      end
    end

    def filter_hash(data, allowlist, global_filter)
      data.each do |key, value|
        data[key] = filter_value(key.to_s, value, allowlist, global_filter)
      end
      data
    end

    def filter_value(key_string, value, allowlist, global_filter)
      if value.is_a?(Hash) || value.is_a?(Array)
        apply_allowlist_filter(value, allowlist, global_filter)
      elsif allowlist.include?(key_string)
        value
      else
        global_filter.call(key_string, value)
      end
    end
  end
end
