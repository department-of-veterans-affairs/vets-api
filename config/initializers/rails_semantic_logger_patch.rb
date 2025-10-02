# frozen_string_literal: true

# Unsubscribe from rails_semantic_logger's send_data notifications to prevent PII in filenames from being logged

Rails.application.config.after_initialize do
  # Unsubscribe only rails_semantic_logger from send_data.action_controller notifications
  # to prevent logging of filenames that may contain PII
  ActiveSupport::Notifications.notifier.listeners_for('send_data.action_controller').each do |subscriber|
    if subscriber.respond_to?(:delegate) && subscriber.delegate.class.name.include?('SemanticLogger')
      ActiveSupport::Notifications.unsubscribe(subscriber)
    end
  end

  # As an additional safeguard, ensure 'filename' is not in the filter parameters allowlist
  # Note: This won't affect rails_semantic_logger's direct logging, but ensures
  # filename parameters are filtered in other contexts
  if defined?(ALLOWLIST) && ALLOWLIST.include?('filename')
    Rails.logger.warn('WARNING: "filename" parameter found in ALLOWLIST - this may expose PII in logs')
  end

  # Log that we've unsubscribed for debugging purposes
  Rails.logger.info('Unsubscribed rails_semantic_logger from send_data.action_controller to prevent PII logging')
end
