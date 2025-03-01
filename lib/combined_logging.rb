# frozen_string_literal: true

require 'sentry_logging'
require 'shared_rails_logging'

module CombinedLogging
  include SentryLogging
  include SharedRailsLogging

  def log_message_all(message, level, extra_context = {}, tags_context = {})
    log_message(message, level, extra_context)
    log_message_to_sentry(message, level, extra_context, tags_context, false)
  end
end
