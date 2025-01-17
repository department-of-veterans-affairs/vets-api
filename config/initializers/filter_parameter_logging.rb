# frozen_string_literal: true

# Be sure to restart your server when you modify this file.

# Configure sensitive parameters which will be filtered from the log file.
ALLOWLIST = %w[
  action
  category
  code
  controller
  cookie_id
  document_id
  document_type
  endDate
  endpoint_sid
  excludeProvidedMessage
  filter
  folder_id
  from_date
  id
  ids
  included
  message_id
  number
  os_name
  page
  qqtotalfilesize
  reply_id
  showCompleted
  size
  sort
  startDate
  startedFormVersion
  to_date
  type
  useCache
].freeze

Rails.application.config.filter_parameters = [
  lambda do |key, value|
    # If the parameter key is not allowed, filter the value.
    if ALLOWLIST.include?(key)
      # Key is in allowlist, so leave value as is.
      value
    else
      case value
      when String
        # For strings, we can mutate in place.
        value.replace 'FILTERED'
      when Numeric
        # Numbers are immutable; return a filtered string.
        'FILTERED'
      when ActionDispatch::Http::UploadedFile
        # For uploaded files, filter out the filename.
        'FILTERED FILE'
      else
        # For other objects (arrays, hashes), Rails will recurse and call this
        # lambda for each element/key/value pair. If there's something else you
        # want to filter, you can handle it similarly.
        value
      end
    end
  end
]
