# frozen_string_literal: true

module Search
  module PiiRedactor
    REDACTION_PLACEHOLDER = '[REDACTED]'

    EMAIL_PATTERN = /[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/i
    SSN_PATTERN = /\b(?!000|666|9\d{2})\d{3}-?(?!00)\d{2}-?(?!0{4})\d{4}\b/
    PHONE_PATTERN = /(\+?\d{1,2}\s?)?\(?\b\d{3}\)?[\s.-]?\d{3}[\s.-]?\d{4}\b/
    ZIP_CODE_PATTERN = /\b\d{5}(?:-\d{4})?\b/
    STREET_ADDRESS_PATTERN =
      /\b\d+\s+[A-Z0-9\s.#]+(?:Street|St\.?|Avenue|Ave\.?|Road|Rd\.?|Boulevard|Blvd\.?|Drive|Dr\.?|Lane|Ln\.?|Court|Ct\.?|Place|Pl\.?|Way|Circle|Cir\.?|Highway|Hwy\.?)\b/i

    module_function

    def redact(value, placeholder = REDACTION_PLACEHOLDER)
      case value
      when String
        redact_string(value, placeholder)
      when Array
        value.map { |item| redact(item, placeholder) }
      when Hash
        value.transform_values { |item| redact(item, placeholder) }
      else
        value
      end
    end

    def redact_string(str, placeholder)
      return str if str.empty?

      redacted = str.dup
      redacted = redacted.gsub(EMAIL_PATTERN, type_placeholder('email', placeholder))
      redacted = redacted.gsub(SSN_PATTERN, type_placeholder('ssn', placeholder))
      redacted = redacted.gsub(PHONE_PATTERN, type_placeholder('phone', placeholder))
      redacted = redacted.gsub(ZIP_CODE_PATTERN, type_placeholder('zip', placeholder))
      redacted.gsub(STREET_ADDRESS_PATTERN, type_placeholder('address', placeholder))
    end

    def type_placeholder(pii_type, base_placeholder)
      return "[REDACTED - #{pii_type}]" if base_placeholder == REDACTION_PLACEHOLDER

      "#{base_placeholder} - #{pii_type}"
    end
  end
end
