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
].freeze
Rails.application.config.filter_parameters = [lambda do |k, v|
  v.replace('FILTERED') if v.is_a?(String) && ALLOWLIST.exclude?(k)
end]
