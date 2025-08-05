# frozen_string_literal: true

# Be sure to restart your server when you modify this file.

# Configure sensitive parameters which will be filtered from the log file.
ALLOWLIST = %w[
  action
  benefits_intake_uuid
  call_location
  category
  claim_id
  class
  code
  confirmation_number
  content_type
  controller
  cookie_id
  document_id
  document_type
  endDate
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
  included
  kafka_payload
  line
  message
  message_id
  number
  os_name
  page
  persistent_attachment_id
  qqtotalfilesize
  reply_id
  saved_claim_id
  service
  showCompleted
  size
  sort
  startDate
  startedFormVersion
  status
  submission_id
  tags
  tempfile
  to_date
  type
  useCache
  use_v2
  user_account_uuid
].freeze

Rails.application.config.filter_parameters = [
  lambda do |k, v|
    case v
    when Hash # Recursively iterate over each key value pair in hashes
      v.each_with_object({}) do |(nested_key, nested_value), result|
        key = nested_key.is_a?(String) ? nested_key : nested_key.to_sym
        result[key] = if ALLOWLIST.include?(nested_key.to_s)
                        nested_value
                      else
                        Rails.application.config.filter_parameters.first&.call(nested_key, nested_value)
                      end
      end
    when Array # Recursively map all elements in arrays
      v.map { |element| Rails.application.config.filter_parameters.first&.call(k, element) }
    when ActionDispatch::Http::UploadedFile # Base case
      v.instance_variables.each do |var| # could put specific instance vars here, but made more generic
        var_name = var.to_s.delete_prefix('@')
        v.instance_variable_set(var, '[FILTERED!]') unless ALLOWLIST.include?(var_name)
      end
      v
    when String # Base case
      # Apply filtering only if the key is NOT in the ALLOWLIST
      v.replace('[FILTERED]') unless ALLOWLIST.include?(k.to_s)
    end
  end
]
