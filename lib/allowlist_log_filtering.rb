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
  # Regex to match object inspect output: #<ClassName @attr=value, @attr2=value2>
  # or #<ClassName attr: value, attr2: value2>
  OBJECT_INSPECT_PATTERN = /#<[A-Z][A-Za-z0-9:]*\s+.*>/
  # Matches @attr="value" or @attr=value patterns in inspect strings
  INSTANCE_VAR_PATTERN = /@(\w+)=("[^"]*"|'[^']*'|\S+)/
  # Matches attr: "value" or attr: value patterns (Ruby inspect style)
  ATTR_COLON_PATTERN = /(\w+):\s*("[^"]*"|'[^']*'|\S+)/

  def add(severity, message = nil, progname = nil, log_allowlist: [], &block)
    severity_int = Logger::Severity.const_get(severity.to_s.upcase)

    # Convert log_allowlist to strings for consistent comparison
    allowlist = log_allowlist.map(&:to_s)

    # Handle block form: logger.info(log_allowlist: [:email]) { data }
    message = block.call if block && message.nil?

    filtered_message = filter_message(message, allowlist)
    super(severity_int, filtered_message, progname)
  end

  # Override all log level methods to support log_allowlist parameter
  # while maintaining backward compatibility with existing patterns:
  # - logger.info(message)
  # - logger.info(message, progname)
  # - logger.info(message, arg2, arg3) - legacy 3-arg pattern
  # - logger.info(key: value) - keyword args as message
  # - logger.info(message, log_allowlist: [...]) - new feature
  %i[debug info warn error fatal unknown].each do |level|
    define_method(level) do |*args, log_allowlist: [], **payload, &block|
      if payload.any?
        # Keyword arguments (other than log_allowlist) become the message hash
        add(level, payload, args.first, log_allowlist:, &block)
      elsif args.length >= 2
        # Two or more positional args: combine into single message string
        # This handles patterns like: logger.info('Contact Info', http_verb, type)
        combined_message = args.map(&:to_s).join(' ')
        add(level, combined_message, nil, log_allowlist:, &block)
      elsif args.length == 1
        # Single arg
        add(level, args.first, nil, log_allowlist:, &block)
      else
        # Block only
        add(level, nil, nil, log_allowlist:, &block)
      end
    end
  end

  private

  def filter_message(message, allowlist)
    case message
    when Hash
      filter_hash_message(message, allowlist)
    when String
      filter_string_message(message, allowlist)
    else
      message
    end
  end

  def filter_hash_message(message, allowlist)
    if allowlist.any?
      filter_with_allowlist(message, allowlist)
    else
      ParameterFilterHelper.filter_params(message)
    end
  end

  def filter_string_message(message, allowlist)
    return message unless message.match?(OBJECT_INSPECT_PATTERN)

    filter_object_inspect(message, allowlist)
  end

  def filter_object_inspect(message, allowlist)
    combined_allowlist = build_combined_allowlist(allowlist)
    result = message.dup
    result = filter_instance_vars(result, combined_allowlist)
    filter_colon_attrs(result, combined_allowlist)
  end

  def build_combined_allowlist(allowlist)
    global_allowlist = defined?(ALLOWLIST) ? ALLOWLIST : []
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
