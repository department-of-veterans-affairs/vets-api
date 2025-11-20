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
      # Apply filtering only if the key is NOT in the ALLOWLIST
      if ALLOWLIST.include?(k.to_s)
        v
      elsif v.respond_to?(:replace) && v.is_a?(String)
        v.replace('[FILTERED]')
      else
        '[FILTERED]'
      end
    end
  end
]
