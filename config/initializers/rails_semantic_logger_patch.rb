# frozen_string_literal: true

# Patch for rails_semantic_logger to prevent logging of send_data filename parameters
# which may contain PII (Personal Identifiable Information) in veteran uploaded file names.
#
# The rails_semantic_logger gem automatically subscribes to ActiveSupport::Notifications
# for 'send_data.action_controller' events and logs the filename parameter. This bypasses
# Rails' filter_parameters configuration, potentially exposing sensitive information.
#
# This patch unsubscribes from that notification to prevent PII exposure in logs.
#
# Reference: https://github.com/department-of-veterans-affairs/va.gov-team-sensitive/issues/4376
# Reference: https://github.com/reidmorrison/rails_semantic_logger/issues/230

Rails.application.config.after_initialize do
  # Unsubscribe from send_data.action_controller notifications to prevent
  # logging of filenames that may contain PII
  ActiveSupport::Notifications.unsubscribe('send_data.action_controller')

  # As an additional safeguard, ensure 'filename' is not in the filter parameters allowlist
  # Note: This won't affect rails_semantic_logger's direct logging, but ensures
  # filename parameters are filtered in other contexts
  if defined?(ALLOWLIST) && ALLOWLIST.include?('filename')
    Rails.logger.warn('WARNING: "filename" parameter found in ALLOWLIST - this may expose PII in logs')
  end

  # Log that we've unsubscribed for debugging purposes
  Rails.logger.info('Unsubscribed from send_data.action_controller notifications to prevent PII logging')
end
