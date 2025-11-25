# frozen_string_literal: true

# Logstop configuration for content-based PII filtering in Rails logs
#
# This provides defense-in-depth alongside our existing filter_parameters
# configuration. While filter_parameters blocks specific parameter names,
# Logstop scans actual content for PII patterns.
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
# Log Coverage:
# - Applies to ALL Rails.logger calls (both developer-generated and framework-generated)
# - Filters log messages before they reach any destination (file, stdout, CloudWatch, DataDog)
# - Covers exception handling and stack traces logged through Rails.logger
# - Does NOT filter logs written directly to STDOUT/STDERR without using Rails.logger
# - Implementation: Sink-level redaction (filters at logger level before broadcast)
#
# Important: This filters ONLY the log message string, NOT structured metadata.
# For structured logging with metadata hashes, use filter_parameters:
#   Rails.logger.info('User action', { ssn: '123-45-6789' })  # ssn filtered by filter_parameters
#   Rails.logger.info('User SSN is 123-45-6789')              # SSN filtered by Logstop
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

# Guard all Rails loggers with Logstop
# This applies filtering to all log outputs (file, stdout, CloudWatch, DataDog)
Logstop.guard(Rails.logger, scrubber: VAPiiScrubber.custom_scrubber)

# Also guard the tagged logger if present
if Rails.logger.respond_to?(:broadcast_to)
  Rails.logger.broadcasts.each do |broadcast|
    Logstop.guard(broadcast, scrubber: VAPiiScrubber.custom_scrubber) if broadcast.respond_to?(:info)
  end
end

Rails.logger.info('Logstop PII filtering initialized with VA-specific patterns')
