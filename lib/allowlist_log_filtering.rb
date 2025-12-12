# frozen_string_literal: true

# AllowlistLogFiltering
#
# This module extends Rails.logger (SemanticLogger) to support per-call allowlist filtering.
# It allows individual log calls to specify which sensitive keys should NOT be filtered,
# providing more granular control than the global ALLOWLIST.
#
# Usage:
#   Rails.logger.info("User data", { ssn: "123-45-6789", email: "user@example.com" }, log_allowlist: [:email])
#   # => User data -- {:ssn=>"[FILTERED]", :email=>"user@example.com"}
#
# The log_allowlist parameter accepts an array of symbols or strings representing
# keys that should bypass filtering for that specific log call.
#
# IMPORTANT: This module is designed for SemanticLogger, not standard Ruby Logger.
# SemanticLogger method signature: info(message=nil, payload=nil, exception=nil, &block)
module AllowlistLogFiltering
  # Regex to match object inspect output: #<ClassName @attr=value, @attr2=value2>
  # or #<ClassName attr: value, attr2: value2>
  OBJECT_INSPECT_PATTERN = /#<[A-Z][A-Za-z0-9:]*\s+.*>/
  # Matches @attr="value" or @attr=value patterns in inspect strings
  INSTANCE_VAR_PATTERN = /@(\w+)=("[^"]*"|'[^']*'|\S+)/
  # Matches attr: "value" or attr: value patterns (Ruby inspect style)
  ATTR_COLON_PATTERN = /(\w+):\s*("[^"]*"|'[^']*'|\S+)/

  # Shadow SemanticLogger's log level methods to support log_allowlist parameter
  # while preserving the original SemanticLogger method signature and behavior.
  # Using extend() adds these methods to the singleton class, which takes precedence
  # over the original instance methods.
  #
  # SemanticLogger signature: level(message=nil, payload=nil, exception=nil, &block)
  # Our extension adds: log_allowlist: [] keyword argument
  SemanticLogger::LEVELS.each do |level|
    define_method(level) do |message = nil, payload = nil, exception = nil, log_allowlist: [], &block|
      # Convert log_allowlist to strings for consistent comparison
      allowlist = Array(log_allowlist).map(&:to_s)

      begin
        # Filter the payload hash if present and allowlist is specified
        filtered_payload = filter_payload(payload, allowlist)

        # Filter message if it's a string containing object inspect pattern
        filtered_message = filter_message_string(message, allowlist)
      rescue => e
        # If filtering fails, log the original data rather than breaking the log call
        # This ensures logging never fails due to filtering issues
        Rails.logger.warn("AllowlistLogFiltering error: #{e.message}") if defined?(Rails.logger)
        filtered_payload = payload
        filtered_message = message
      end

      # Call the original SemanticLogger method with filtered data
      super(filtered_message, filtered_payload, exception, &block)
    end
  end

  private

  def filter_payload(payload, allowlist)
    return payload unless payload.is_a?(Hash)

    if allowlist.any?
      filter_with_allowlist(payload, allowlist)
    else
      # Use default filtering when no per-call allowlist
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
    # Get the global filter lambda from Rails config
    # filter_parameters is expected to be an array with a lambda as the first element
    filter_params = Rails.application.config.filter_parameters
    global_filter = filter_params.is_a?(Array) && filter_params.any? ? filter_params.first : nil

    # Fallback to standard filtering when no global filter exists or is invalid
    return ParameterFilterHelper.filter_params(data) unless global_filter.respond_to?(:call)

    # Create a custom filter that respects the per-call allowlist
    # deep_dup is required because filter_hash mutates hashes in-place via data[key] = ...
    # Without this, the caller's original payload would be modified with [FILTERED] values
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
