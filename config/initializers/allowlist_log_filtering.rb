# frozen_string_literal: true

require 'allowlist_log_filtering'

# Extend Rails.logger with AllowlistLogFiltering to support per-call allowlist parameter
# This allows individual log calls to specify which keys should not be filtered
# Usage: Rails.logger.info(data, log_allowlist: [:email, :phone])
Rails.application.config.after_initialize do
  Rails.logger.extend(AllowlistLogFiltering)
  Rails.logger.debug('AllowlistLogFiltering enabled - log_allowlist parameter now available')
end
