# frozen_string_literal: true

# Logstop configuration for opt-in content-based PII filtering in Rails logs
#
# IMPLEMENTATION: OPT-IN ONLY
#
# This provides defense-in-depth alongside our existing filter_parameters
# configuration. While filter_parameters blocks specific parameter names,
# Logstop scans actual content for PII patterns.
#
# USAGE:
#   Use VAPiiLogger.filtered when logging potentially sensitive data:
#
#   # Standard logging (no PII filtering overhead)
#   Rails.logger.info('Processing request')
#
#   # Filtered logging (use when logging user input or sensitive data)
#   VAPiiLogger.filtered.info("User submitted: #{user_params}")
#
# Built-in patterns filtered by Logstop:
# - SSN (XXX-XX-XXXX)
# - Email addresses
# - Phone numbers
# - Credit card numbers
# - IPv4 addresses (NOT filtered - Logstop does not support IP filtering by default)
# - IPv6 addresses (NOT filtered - Logstop does not support IP filtering by default)
#
# Note: IP addresses (IPv4/IPv6) are NOT filtered by default. Logstop does not
# include IP address patterns in its built-in filters. If IP address filtering
# is required, custom patterns would need to be added to the scrubber below.
#
# Custom VA-specific patterns added below:
# - VA file numbers (8-9 digit numbers)
# - SSN without dashes (9 digits)
# - EDIPI (10 digits)
#
# Performance Impact:
# - Per-line overhead: ~2.5µs (50x slower than unfiltered logging)
# - Only applies when using VAPiiLogger.filtered (zero impact on Rails.logger)
# - See spec/lib/logstop_performance_spec.rb for benchmarks
#
# Important: This filters ONLY the log message string, NOT structured metadata.
# For structured logging with metadata hashes, use filter_parameters:
#   Rails.logger.info('User action', { ssn: '123-45-6789' })  # ssn filtered by filter_parameters
#   VAPiiLogger.filtered.info('User SSN is 123-45-6789')      # SSN filtered by Logstop
#
# Reference: https://github.com/ankane/logstop
# Related ticket: https://github.com/department-of-veterans-affairs/va.gov-team/issues/120874

require 'logstop'

# Module to hold VA-specific PII scrubber for use in initializer and tests
module VAPiiScrubber
  # Returns the custom scrubber lambda for VA-specific PII patterns
  # These patterns are not covered by Logstop's built-in filters
  def self.custom_scrubber
    lambda do |msg|
      # First apply Logstop's built-in patterns (SSN, email, phone, credit cards)
      msg = Logstop.scrub(msg)

      # Then apply VA-specific patterns

      # VA file numbers (8-9 digit numbers that could be veteran identifiers)
      # Using word boundaries to avoid matching other numeric sequences
      msg = msg.gsub(/\bVA\s*(?:file\s*)?(?:number|#|no\.?)?:?\s*(\d{8,9})\b/i,
                     'VA file number: [VA_FILE_NUMBER_FILTERED]')

      # Standalone 9-digit numbers that look like SSNs without dashes
      # (Logstop handles XXX-XX-XXXX format, this catches XXXXXXXXX)
      msg = msg.gsub(/\b(?<!\d)(\d{9})(?!\d)\b/, '[SSN_FILTERED]')

      # EDIPI (10 digit DoD identifier)
      # Note: 10-digit numbers are more common (order numbers, tracking IDs, etc.)
      # so this pattern has higher false positive risk. We accept this tradeoff
      # because over-filtering is preferable to leaking PII. Phone numbers are
      # already handled by Logstop's built-in patterns. If false positives become
      # problematic, consider context-based matching (e.g., requiring "EDIPI:" prefix).
      msg = msg.gsub(/\b(?<!\d)(\d{10})(?!\d)\b/, '[EDIPI_FILTERED]')

      msg
    end
  end
end

# Opt-in filtered logger for sensitive contexts
module VAPiiLogger
  # Returns a logger with PII filtering enabled
  # Use this when logging potentially sensitive data (user input, form submissions, etc.)
  #
  # Example:
  #   VAPiiLogger.filtered.info("User submitted claim: #{claim_params}")
  #
  # Note: This incurs ~2.5µs overhead per log line. Only use when necessary.
  def self.filtered
    # Thread-safe singleton using class variable
    @@filtered_logger ||= begin # rubocop:disable Style/ClassVars
      logger = ActiveSupport::Logger.new($stdout)
      logger.level = Rails.logger.level
      logger.formatter = Rails.logger.formatter
      Logstop.guard(logger, scrubber: VAPiiScrubber.custom_scrubber)
      logger
    end
  end
end

Rails.logger.info('Logstop PII filtering available via VAPiiLogger.filtered (opt-in only)')
