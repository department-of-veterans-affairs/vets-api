# frozen_string_literal: true

module Logging
  # DataScrubber provides utilities for removing Personally Identifiable Information (PII)
  # and sensitive data from log messages, API responses, and other data structures.
  #
  # This module recursively processes nested data structures (hashes, arrays, strings)
  # and replaces sensitive information with '[REDACTED]' to prevent PII leakage in logs.
  #
  # @example Basic usage
  #   data = { name: "John Doe", ssn: "123-45-6789", contact: { email: "john@example.com" } }
  #   Logging::DataScrubber.scrub(data)
  #   # => { name: "John Doe", ssn: "[REDACTED]", contact: { email: "[REDACTED]" } }
  #
  # @example With arrays
  #   data = ["Call me at 555-123-4567", { credit_card: "4444-4444-4444-4444" }]
  #   Logging::DataScrubber.scrub(data)
  #   # => ["Call me at [REDACTED]", { credit_card: "[REDACTED]" }]
  #
  # @example Flipper feature toggle
  #   # If the :logging_data_scrubber flipper is disabled, data is returned unchanged
  #   Flipper.disable(:logging_data_scrubber)
  #   Logging::DataScrubber.scrub({ ssn: "123-45-6789" })
  #   # => { ssn: "123-45-6789" } (unchanged)
  #
  module DataScrubber
    # Regular expressions for detecting various types of PII and sensitive data

    # Social Security Numbers: 123-45-6789, 123456789, 123 45 6789
    SSN_REGEX = /\b\d{3}[-\s]?\d{2}[-\s]?\d{4}\b/

    # Email addresses: user@example.com, test.email+tag@domain.co.uk
    EMAIL_REGEX = /\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b/i

    # ICN (Integration Control Number): 1234567890V123456 (most specific, check first)
    ICN_REGEX = /\b\d{10}V\d{6}\b/

    # EDIPI (DoD Electronic Data Interchange Person Identifier): 1234567890 (10 digits exactly)
    EDIPI_REGEX = /\b\d{10}\b(?!V\d{6})/

    # Bank routing numbers: 123456789 (9 digits exactly, not 8 or 10+)
    ROUTING_NUMBER_REGEX = /\b\d{9}\b(?!\d)/

    # VA Participant ID: 12345678 (8 digits exactly)
    PARTICIPANT_ID_REGEX = /\b\d{8}\b(?!\d)/

    # VA file numbers: C12345678, C-12345678 (must have C prefix)
    VA_FILE_NUMBER_REGEX = /\bC-?\d{8,9}\b/

    # Phone numbers: (555) 123-4567, 555-123-4567, +1-555-123-4567, 5551234567, 555-1234
    PHONE_REGEX = /
      \(\d{3}\)\s\d{3}-\d{4}|     # (555) 123-4567
      \+?1?\s?\d{3}\s\d{3}\s\d{4}| # +1 555 123 4567, 555 123 4567
      \+?1?-?\d{3}-\d{3}-\d{4}|    # +1-555-123-4567, 555-123-4567
      \b\d{3}-\d{4}\b|             # 555-1234
      \b\d{10}\b                   # 5551234567
    /x

    # Credit card numbers: 4444-4444-4444-4444, 4444 4444 4444 4444, 4444444444444444
    CREDIT_CARD_REGEX = /\b\d{4}[-\s]\d{4}[-\s]\d{4}[-\s]\d{4}\b|\b\d{16}\b/

    # ZIP codes: 12345, 12345-6789 (but not order numbers like "Order #12345" or credit card digits)
    ZIP_CODE_REGEX = /\b(?<!#)(?<!-)(?:\d{5}-\d{4}\b|\d{5}(?![-]\d))\b/

    # Birth dates: 01/15/1985, 1-15-1985, 01.15.1985, 12/31/2000
    BIRTH_DATE_REGEX = %r{\b(?:0?[1-9]|1[0-2])[/\-.](?:0?[1-9]|[12][0-9]|3[01])[/\-.](?:19|20)\d{2}\b}

    # The string used to replace detected PII
    REDACTION = '[REDACTED]'

    SAFE_KEYS = %w[confirmation_number user_account_uuid claim_id form_id tags id].freeze

    module_function

    # Recursively scrubs PII from any data structure (Hash, Array, String, or other types).
    #
    # This method serves as the main entry point for data scrubbing. It respects the
    # :logging_data_scrubber Flipper feature flag - if disabled, data is returned unchanged.
    #
    # @param data [Object] The data to scrub. Can be a Hash, Array, String, or any other type.
    # @return [Object] A new data structure with PII replaced by '[REDACTED]'.
    #   - Strings: PII patterns are replaced with REDACTION constant
    #   - Hashes: Values are recursively scrubbed, keys remain unchanged
    #   - Arrays: Each element is recursively scrubbed
    #   - Other types: Returned unchanged
    #
    # @example
    #   scrub("Call me at 555-123-4567")
    #   # => "Call me at [REDACTED]"
    #
    #   scrub({ name: "John", contact: ["john@email.com", "555-1234"] })
    #   # => { name: "John", contact: ["[REDACTED]", "[REDACTED]"] }
    #
    def scrub(data)
      return data unless Flipper.enabled?(:logging_data_scrubber)

      scrub_value(data)
    end

    # Internal recursive method that handles different data types.
    #
    # @param value [Object] The value to scrub
    # @return [Object] The scrubbed value
    # @api private
    def scrub_value(value)
      case value
      when String
        scrub_string(value)
      when Hash
        # Recursively scrub hash values while preserving keys, except for SAFE_KEYS
        value.each_with_object({}) do |(k, v), result|
          result[k] = SAFE_KEYS.include?(k.to_s) ? v : scrub_value(v)
        end
      when Array
        # Recursively scrub each array element
        value.map { |item| scrub_value(item) }
      else
        # Return non-string, non-collection types unchanged (numbers, booleans, nil, etc.)
        value
      end
    end

    # Applies all PII regex patterns to scrub sensitive information from strings.
    #
    # @param message [String] The string to scrub
    # @return [String] The string with PII replaced by REDACTION constant
    # @api private
    #
    # @note Returns the original string unchanged if it's blank (nil, empty, or whitespace-only)
    #
    # @example
    #   scrub_string("My SSN is 123-45-6789 and email is test@example.com")
    #   # => "My SSN is [REDACTED] and email is [REDACTED]"
    #
    def scrub_string(message)
      return message if message.blank?

      # Combined regex pattern for all PII types
      # Order matters: most specific patterns first to avoid conflicts
      combined_regex = /
        #{ICN_REGEX}|
        #{SSN_REGEX}|
        #{EMAIL_REGEX}|
        #{PHONE_REGEX}|
        #{CREDIT_CARD_REGEX}|
        #{BIRTH_DATE_REGEX}|
        #{VA_FILE_NUMBER_REGEX}|
        #{EDIPI_REGEX}|
        #{ROUTING_NUMBER_REGEX}|
        #{PARTICIPANT_ID_REGEX}|
        #{ZIP_CODE_REGEX}
      /x

      # Apply all PII detection patterns and replace matches with REDACTION
      message.gsub(combined_regex, REDACTION)
    end
  end
end
