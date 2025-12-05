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
  %i[debug info warn error fatal unknown].each do |level|
    define_method(level) do |progname = nil, log_allowlist: [], &block|
      add(level, progname, nil, log_allowlist:, &block)
    end
  end

  private

  def filter_with_allowlist(data, allowlist)
    # Get the global filter lambda from Rails config
    global_filter = Rails.application.config.filter_parameters.first

    return data unless global_filter

    # Create a custom filter that respects the per-call allowlist
    filtered_data = data.deep_dup

    apply_allowlist_filter(filtered_data, allowlist, global_filter)
  end

  def apply_allowlist_filter(data, allowlist, global_filter)
    case data
    when Hash
      data.each do |key, value|
        key_string = key.to_s

        data[key] = if allowlist.include?(key_string)
                      # Key is in the per-call allowlist, don't filter it
                      value
                    elsif value.is_a?(Hash) || value.is_a?(Array)
                      # Recursively filter nested structures
                      apply_allowlist_filter(value, allowlist, global_filter)
                    else
                      # Apply global filtering
                      global_filter.call(key, value)
                    end
      end
      data
    when Array
      data.map { |element| apply_allowlist_filter(element, allowlist, global_filter) }
    else
      data
    end
  end
end
