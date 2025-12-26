# frozen_string_literal: true

module Logging
  module Helper
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
    module DataScrubber
      # uuid matcher
      UUID_REGEX = /[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}/i

      # Regular expressions for detecting various types of PII and sensitive data
      REGEX = {
        # Social Security Numbers: 123-45-6789, 123456789, 123 45 6789
        SSN: /\b\d{3}[-\s]?\d{2}[-\s]?\d{4}\b/,

        # Email addresses: user@example.com, test.email+tag@domain.co.uk
        EMAIL: /\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b/i,

        # ICN (Integration Control Number): 1234567890V123456 (most specific, check first)
        ICN: /\b\d{10}V\d{6}\b/,

        # EDIPI (DoD Electronic Data Interchange Person Identifier): 1234567890 (10 digits exactly)
        EDIPI: /\b\d{10}\b(?!V\d{6})/,

        # Bank routing numbers: 123456789 (9 digits exactly, not 8 or 10+)
        ROUTING_NUMBER: /\b\d{9}\b(?!\d)/,

        # VA Participant ID: 12345678 (8 digits exactly)
        PARTICIPANT_ID: /\b\d{8}\b(?!\d)/,

        # VA file numbers: C12345678, C-12345678 (must have C prefix)
        VA_FILE_NUMBER: /\bC-?\d{8,9}\b/,

        # Phone numbers: (555) 123-4567, 555-123-4567, +1-555-123-4567, 5551234567, 555-1234
        PHONE: /
          \(\d{3}\)\s\d{3}-\d{4}|     # (555) 123-4567
          \+?1?\s?\d{3}\s\d{3}\s\d{4}| # +1 555 123 4567, 555 123 4567
          \+?1?-?\d{3}-\d{3}-\d{4}|    # +1-555-123-4567, 555-123-4567
          \b\d{3}-\d{4}\b|             # 555-1234
          \b\d{10}\b                   # 5551234567
        /x,

        # Credit card numbers: 4444-4444-4444-4444, 4444 4444 4444 4444, 4444444444444444
        CREDIT_CARD: /\b\d{4}[-\s]\d{4}[-\s]\d{4}[-\s]\d{4}\b|\b\d{16}\b/,

        # ZIP codes: 12345, 12345-6789 (but not order numbers like "Order #12345" or credit card digits)
        ZIP_CODE: /\b(?<!#)(?<!-)(?:\d{5}-\d{4}\b|\d{5}(?!-\d))\b/,

        # Birth dates: 01/15/1985, 1-15-1985, 01.15.1985, 12/31/2000
        BIRTH_DATE: %r{\b(?:0?[1-9]|1[0-2])[/\-.](?:0?[1-9]|[12][0-9]|3[01])[/\-.](?:19|20)\d{2}\b}
      }.freeze

      # Order matters: most specific patterns first to avoid conflicts
      PATTERN_ORDER = %i[
        ICN
        SSN
        EMAIL
        PHONE
        CREDIT_CARD
        BIRTH_DATE
        VA_FILE_NUMBER
        EDIPI
        ROUTING_NUMBER
        PARTICIPANT_ID
        ZIP_CODE
      ].freeze

      # Patterns that could match UUID segments and need exclusion
      UUID_SENSITIVE_PATTERNS = %i[SSN EDIPI ROUTING_NUMBER PARTICIPANT_ID PHONE CREDIT_CARD ZIP_CODE].freeze

      # The string used to replace detected PII
      REDACTION = '[REDACTED]'

      # protected keys not to be scrubbed
      SAFE_KEYS = %w[
        claim_id
        completely_removed
        confirmation_number
        form_id
        id
        in_progress_form_id
        removed_keys
        response_code
        saved_claim_id
        submission_id
        tags
        user_account_uuid
      ].freeze

      module_function

      # Recursively scrubs PII from any data structure (Hash, Array, String, or other types).
      #
      # This method serves as the main entry point for data scrubbing.
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
      def scrub(data, safe_keys: [])
        keys_to_skip = SAFE_KEYS + safe_keys.map(&:to_s)
        scrub_value(data, keys_to_skip)
      rescue => e
        Rails.logger.error("DataScrubber failed: #{e.class} - #{e.message}")
        data # Return original data on failure to avoid blocking logging
      end

      # Internal recursive method that handles different data types.
      #
      # @param value [Object] The value to scrub
      # @return [Object] The scrubbed value
      # @api private
      def scrub_value(value, keys_to_skip)
        case value
        when String
          scrub_string(value)
        when Hash
          # Recursively scrub hash values while preserving keys, except for keys_to_skip
          value.each_with_object({}) do |(k, v), result|
            result[k] = keys_to_skip.include?(k.to_s) ? v : scrub_value(v, keys_to_skip)
          end
        when Array
          # Recursively scrub each array element
          value.map { |item| scrub_value(item, keys_to_skip) }
        when NilClass, TrueClass, FalseClass
          # Preserve nil and boolean values as-is
          value
        else
          # Cast all other leaf nodes to string and scrub to catch numeric PII
          # This ensures SSNs, credit cards, phone numbers stored as integers are caught
          result = scrub_string(value.to_s)

          # If no PII was found in the string representation, return the original value
          result.include?(REDACTION) ? result : value
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
      def scrub_string(message)
        return message if message.blank?

        # Build combined regex pattern from all REGEX patterns
        combined_regex = Regexp.new(
          PATTERN_ORDER.map { |key| REGEX[key] }.join('|'),
          Regexp::EXTENDED
        )

        # Apply all PII detection patterns and replace matches with REDACTION
        message.gsub(combined_regex) do |match|
          # Get match position from MatchData
          match_data = Regexp.last_match
          match_start = match_data.offset(0)[0]
          match_end = match_data.offset(0)[1]

          # Extract context around the match to check for UUID pattern
          before_match = message[0...match_start] || ''
          after_match = message[match_end..] || ''
          context = before_match[-40..].to_s + match + after_match[0..40].to_s

          if context.match?(UUID_REGEX)
            match # Keep original if it's part of a UUID
          else
            REDACTION # Replace if not part of a UUID
          end
        end
      end
    end
  end
end
