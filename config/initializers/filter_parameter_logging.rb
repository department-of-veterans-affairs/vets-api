# frozen_string_literal: true

# Be sure to restart your server when you modify this file.

# Adding a key here unfilters ALL params with that name across ALL of vets-api.
# Do NOT add keys that can contain PII/PHI/secrets.
ALLOWLIST = %w[
  action
  benefits_intake_uuid
  bpds_uuid
  call_location
  category
  claim_id
  class
  code
  confirmation_number
  consumer_name
  content_type
  controller
  cookie_id
  document_id
  doctype
  document_type
  endDate
  endpoint
  endpoint_sid
  error
  errors
  excludeProvidedMessage
  file_uuid
  filter
  folder_id
  form_id
  from_date
  grant_type
  id
  ids
  in_progress_form_id
  itf_type
  included
  kafka_payload
  line
  lookup_service
  message_id
  method
  number
  os_name
  page
  persistent_attachment_id
  qqtotalfilesize
  queue_time
  reason
  reply_id
  result
  root
  saved_claim_id
  service
  showCompleted
  size
  sort
  stamp_set
  startDate
  startedFormVersion
  statsd
  status
  status_code
  submission_id
  tags
  tempfile
  time_to_transition
  to_date
  to_state
  type
  useCache
  use_v2
  user_account_uuid
].freeze

# PII patterns to detect and filter in string values
# These patterns will be applied to string values even if the key is in the allowlist
PII_PATTERNS = {
  # Email addresses - matches standard email format
  email: /\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b/,

  # Social Security Numbers - matches formats: 123-45-6789, 123456789
  ssn: /\b\d{3}-?\d{2}-?\d{4}\b/,

  # Credit card numbers - matches formats with spaces or dashes: 4111-1111-1111-1111
  credit_card: /\b\d{4}[\s-]?\d{4}[\s-]?\d{4}[\s-]?\d{4}\b/,

  # Phone numbers - matches various US formats
  # (555) 123-4567, 555-123-4567, 555.123.4567, 5551234567, +1-555-123-4567
  phone: /\b(\+?1[\s.-]?)?\(?\d{3}\)?[\s.-]?\d{3}[\s.-]?\d{4}\b/,

  # IP addresses - matches IPv4 format
  ip_address: /\b(?:\d{1,3}\.){3}\d{1,3}\b/,

  # URLs with potential auth tokens in query strings or paths
  # Matches: api_key=, token=, access_token=, auth=, secret= in URLs
  url_with_token: /\b(api_key|token|access_token|auth|secret)=[A-Za-z0-9_\-\.~]+/i,

  # JWT tokens - matches standard JWT format (header.payload.signature)
  jwt_token: /\beyJ[A-Za-z0-9_-]+\.eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\b/,

  # API keys - common formats (sk_, pk_, key_, etc.)
  api_key: /\b(sk|pk|key|api)_[a-zA-Z0-9]{20,}\b/i,

  # Medicare/Medicaid numbers - formats: 1AB2-CD3-EF45, 1234567890A, 1AB-CD-EF01-G2
  medicare: /\b\d[A-Z]{2}\d-[A-Z]{2}\d-[A-Z]{2}\d{2}\b|\b\d{10}[A-Z]\b|\b\d[A-Z]{2}-[A-Z]{2}-[A-Z]{2}\d{2}-[A-Z]\d\b/i,

  # VA File Numbers - typically 8-9 digits, sometimes with prefixes
  va_file_number: /\b[Cc]?\d{8,9}\b/,

  # Dates of birth - various formats: MM/DD/YYYY, MM-DD-YYYY, YYYY-MM-DD
  # Only flag if it looks like a realistic birth date (year between 1900-2025)
  date_of_birth: /\b(0[1-9]|1[0-2])[\/\-](0[1-9]|[12]\d|3[01])[\/\-](19|20)\d{2}\b/
}.freeze

# Minimum length for pattern matching (avoid false positives on short strings)
MIN_PATTERN_MATCH_LENGTH = 5

# Helper method to check if a string contains PII patterns
def self.contains_pii_pattern?(value)
  return false unless value.is_a?(String)
  return false if value.length < MIN_PATTERN_MATCH_LENGTH

  PII_PATTERNS.any? { |_name, pattern| value.match?(pattern) }
end

# Helper method to scrub PII patterns from a string
def self.scrub_pii_patterns(value)
  return value unless value.is_a?(String)
  return value if value.length < MIN_PATTERN_MATCH_LENGTH

  scrubbed = value.dup
  PII_PATTERNS.each do |_name, pattern|
    scrubbed.gsub!(pattern, '[FILTERED]')
  end
  scrubbed
end

# Configure sensitive parameters which will be filtered from the log file.
Rails.application.config.filter_parameters = [
  lambda do |k, v|
    case v
    when Hash # Recursively iterate over each key value pair in hashes
      v.each do |nested_key, nested_value|
        v[nested_key] = Rails.application.config.filter_parameters.first&.call(nested_key, nested_value)
      end
      v
    when Array # Recursively map all elements in arrays
      v.map! { |element| Rails.application.config.filter_parameters.first&.call(k, element) }
      v
    when ActionDispatch::Http::UploadedFile # Base case
      v.instance_variables.each do |var| # could put specific instance vars here, but made more generic
        var_name = var.to_s.delete_prefix('@')
        v.instance_variable_set(var, '[FILTERED!]') unless ALLOWLIST.include?(var_name)
      end
      v
    else # Base case for all other types (String, Integer, Symbol, Class, nil, etc.)
      # Apply filtering based on key allowlist and PII pattern detection
      if ALLOWLIST.include?(k.to_s)
        # Key is in allowlist, but still check for PII patterns in string values
        if v.is_a?(String) && contains_pii_pattern?(v)
          # Pattern detected even though key is allowed - scrub the patterns only
          scrubbed = scrub_pii_patterns(v)
          v.respond_to?(:replace) ? v.replace(scrubbed) : scrubbed
        else
          v
        end
      elsif v.respond_to?(:replace) && v.is_a?(String)
        v.replace('[FILTERED]')
      else
        '[FILTERED]'
      end
    end
  end
]
