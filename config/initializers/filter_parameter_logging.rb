# frozen_string_literal: true

# Be sure to restart your server when you modify this file.

# Configure sensitive parameters which will be filtered from the log file.
WHITELIST = %w(
  controller
  action
  id
  from_date
  to_date
).freeze
Rails.application.config.filter_parameters = [lambda do |k, v|
  if v.is_a?(String)
    v.replace('FILTERED') unless WHITELIST.include?(k)
  end
end]
