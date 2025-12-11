# frozen_string_literal: true

# AllowlistLogFiltering
#
# This module extends Rails.logger to support per-call allowlist filtering.
# It allows individual log calls to specify which sensitive keys should NOT be filtered,
# providing more granular control than the global ALLOWLIST.
#
# Usage:
#   Rails.logger.info("User data", { ssn: "123-45-6789", email: "user@example.com" }, log_allowlist: [:email])
#   # => {:ssn=>"[FILTERED]", :email=>"user@example.com"}
#
# The log_allowlist parameter accepts an array of symbols or strings representing
# keys that should bypass filtering for that specific log call.
module AllowlistLogFiltering
  def add(severity, message = nil, progname = nil, log_allowlist: [])
    severity_int = Logger::Severity.const_get(severity.to_s.upcase)

    # Convert log_allowlist to strings for consistent comparison
    allowlist = log_allowlist.map(&:to_s)

    # If message is a hash, apply filtering (either per-call or default)
    if message.is_a?(Hash)
      filtered_message = if allowlist.any?
                           # Apply per-call allowlist filtering
                           filter_with_allowlist(message, allowlist)
                         else
                           # Apply default Rails filtering (no per-call allowlist)
                           ParameterFilterHelper.filter_params(message)
                         end
      return super(severity_int, filtered_message, progname)
    end

    # Otherwise use default behavior for non-hash messages
    super(severity_int, message, progname)
  end

  # Override all log level methods to support log_allowlist parameter
  # while maintaining backward compatibility with existing patterns:
  # - logger.info(message)
  # - logger.info(message, progname)
  # - logger.info(key: value) - keyword args as message
  # - logger.info(message, log_allowlist: [...]) - new feature
  %i[debug info warn error fatal unknown].each do |level|
    define_method(level) do |message = nil, progname_or_data = nil, log_allowlist: [], **payload, &block|
      if payload.any?
        # Keyword arguments (other than log_allowlist) become the message hash
        add(level, payload, message, log_allowlist:, &block)
      elsif progname_or_data
        # Two positional args: message and progname (standard Logger pattern)
        add(level, message, progname_or_data, log_allowlist:, &block)
      else
        # Single arg or block
        add(level, message, nil, log_allowlist:, &block)
      end
    end
  end

  private

  def filter_with_allowlist(data, allowlist)
    # Get the global filter lambda from Rails config
    global_filter = Rails.application.config.filter_parameters.first

    # Fallback to standard filtering when no global filter exists
    return ParameterFilterHelper.filter_params(data) unless global_filter

    # Create a custom filter that respects the per-call allowlist
    # Note: deep_dup is necessary to avoid mutating the caller's data,
    # but may have performance implications for large data structures
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
      # Always filter nested structures, even if parent key is allowlisted
      apply_allowlist_filter(value, allowlist, global_filter)
    elsif allowlist.include?(key_string)
      # Key is allowlisted and value is not a nested structure
      value
    else
      # Apply global filtering
      global_filter.call(key_string, value)
    end
  end
end
