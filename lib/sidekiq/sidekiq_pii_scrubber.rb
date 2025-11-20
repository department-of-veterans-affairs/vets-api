# frozen_string_literal: true

module Sidekiq
  # Middleware to scrub PII from Sidekiq job arguments before logging
  class PiiScrubber
    # Default PII patterns to scrub
    PII_PATTERNS = {
      # Email addresses
      email: /\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b/,
      # SSN (xxx-xx-xxxx or xxxxxxxxx)
      ssn: /\b\d{3}-?\d{2}-?\d{4}\b/,
      # Credit card numbers (basic pattern)
      credit_card: /\b\d{4}[\s-]?\d{4}[\s-]?\d{4}[\s-]?\d{4}\b/,
      # Phone numbers (various formats)
      phone: /\b(\+\d{1,2}\s?)?\(?\d{3}\)?[\s.-]?\d{3}[\s.-]?\d{4}\b/,
      # IP addresses
      ip_address: /\b(?:\d{1,3}\.){3}\d{1,3}\b/,
    }.freeze

    # Keys that commonly contain PII
    PII_KEYS = %w[
      password password_confirmation
      ssn social_security_number
      credit_card card_number cvv cvc
      email email_address
      phone phone_number mobile_number
      address street_address
      zip_code postal_code
      date_of_birth dob birth_date
      drivers_license
      passport_number
      bank_account routing_number
      token access_token api_key secret
      authorization auth_token
    ].freeze

    REDACTED = '[REDACTED]'

    def initialize(options = {})
      @additional_keys = options[:additional_keys] || []
      @additional_patterns = options[:additional_patterns] || {}
      @preserve_structure = options.fetch(:preserve_structure, true)
    end

    def call(_worker, job, _queue)
      scrub_job!(job)
      yield
    end

    private

    def scrub_job!(job)
      return unless job.is_a?(Hash)

      # Scrub the 'args' field which contains job arguments
      job['args'] = scrub_value(job['args']) if job.key?('args')

      # Optionally scrub other job metadata if needed
      # job['error_message'] = scrub_value(job['error_message']) if job.key?('error_message')
    end

    def scrub_value(value)
      case value
      when Hash
        scrub_hash(value)
      when Array
        value.map { |v| scrub_value(v) }
      when String
        scrub_string(value)
      when Numeric, TrueClass, FalseClass, NilClass
        value
      else
        # For other objects, try to convert to string and scrub
        scrub_string(value.to_s)
      end
    end

    def scrub_hash(hash)
      hash.each_with_object({}) do |(key, value), result|
        if pii_key?(key)
          result[key] = @preserve_structure ? redacted_value(value) : REDACTED
        else
          result[key] = scrub_value(value)
        end
      end
    end

    def scrub_string(string)
      return string if string.nil? || string.empty?

      scrubbed = string.dup

      # Apply pattern-based scrubbing
      all_patterns.each do |_name, pattern|
        scrubbed.gsub!(pattern, REDACTED)
      end

      scrubbed
    end

    def pii_key?(key)
      key_str = key.to_s.downcase
      all_pii_keys.any? { |pii_key| key_str.include?(pii_key) }
    end

    def redacted_value(value)
      case value
      when Hash
        value.transform_values { |_v| REDACTED }
      when Array
        Array.new(value.size, REDACTED)
      when String
        REDACTED
      when Numeric
        0
      when TrueClass, FalseClass
        false
      else
        REDACTED
      end
    end

    def all_pii_keys
      @all_pii_keys ||= (PII_KEYS + @additional_keys).map(&:downcase)
    end

    def all_patterns
      @all_patterns ||= PII_PATTERNS.merge(@additional_patterns)
    end
  end
end
