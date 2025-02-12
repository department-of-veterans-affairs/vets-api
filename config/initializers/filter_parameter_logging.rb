# frozen_string_literal: true

# Be sure to restart your server when you modify this file.

# Configure sensitive parameters which will be filtered from the log file.
ALLOWLIST = %w[
  controller
  action
  id
  from_date
  to_date
  qqtotalfilesize
  type
  folder_id
  startDate
  endDate
  included
  page
  useCache
  number
  size
  sort
  showCompleted
  excludeProvidedMessage
  document_id
  document_type
  category
  cookie_id
  reply_id
  ids
  code
  endpoint_sid
  message_id
  os_name
  filter
  startedFormVersion
  tempfile
  content_type
].freeze

Rails.application.config.filter_parameters = [
  lambda do |k, v|
    case v
    when Hash # Recursively iterate over each key value pair in hashes
      v.transform_values { |nested_value| Rails.application.config.filter_parameters.first.call(k, nested_value) }
    when Array # Recursively map all elements in arrays
      v.map { |element| Rails.application.config.filter_parameters.first.call(k, element) }
    when ActionDispatch::Http::UploadedFile # Base case
      v.instance_variables.each do |var| # could put specific instance vars here, but made more generic
        var_name = var.to_s.delete_prefix('@')
        v.instance_variable_set(var, '[FILTERED!]') unless ALLOWLIST.include?(var_name)
      end
    when String # Base case
      # Apply filtering only if the key is NOT in the ALLOWLIST
      v.replace('[FILTERED]') unless ALLOWLIST.include?(k.to_s)
    end
  end
]
