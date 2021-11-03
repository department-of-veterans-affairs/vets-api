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
].freeze
Rails.application.config.filter_parameters = [lambda do |k, v|
  v.replace('FILTERED') if v.is_a?(String) && ALLOWLIST.exclude?(k)
end]
