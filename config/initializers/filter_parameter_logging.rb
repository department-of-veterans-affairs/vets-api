# frozen_string_literal: true

# Be sure to restart your server when you modify this file.

# Adding a key here unfilters ALL params with that name across ALL of vets-api.
# Do NOT add keys that can contain PII/PHI/secrets.
ALLOWLIST = %w[
  action
  benefits_intake_uuid
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

# This adds log_allowlist: on each call to Rail.logger
# NOTE: this doesn't work with ActionDispatch::Http::UploadedFile
module AllowlistLogFiltering
  %i[debug info warn error fatal unknown].each do |level|
    define_method(level) do |message = nil, params = nil, log_allowlist: []|
      # If only a hash was passed, treat it as params
      if message.is_a?(Hash) && params.nil?
        params = message
        message = nil
      end

      params = filter_hash(params, log_allowlist) if params.is_a?(Hash)

      if params
        super(message ? "#{message} #{params.inspect}" : params.inspect)
      else
        super(message)
      end
    end
  end

  private

  def filter_hash(hash, log_allowlist = [])
    hash.deep_dup.each do |k, v|
      next if ALLOWLIST.include?(k.to_s) || log_allowlist.map(&:to_s).include?(k.to_s)

      hash[k] = case v
                when Hash
                  filter_hash(v, log_allowlist)
                when Array
                  v.map { |el| el.is_a?(Hash) ? filter_hash(el, log_allowlist) : '[FILTERED]' }
                else
                  '[FILTERED]'
                end
    end
    hash
  end
end

Rails.logger.extend(AllowlistLogFiltering)
